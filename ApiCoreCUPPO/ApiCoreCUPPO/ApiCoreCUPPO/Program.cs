using ApiCoreCUPPO.API.Authorization;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Catalog;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Security;
using ApiCoreCUPPO.Application.Interfaces.IRepository.Venue;
using ApiCoreCUPPO.Application.Interfaces.IServices.Catalog;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Security;
using ApiCoreCUPPO.Application.Interfaces.IServices.Venue;
using ApiCoreCUPPO.Application.Services.Catalog;
using ApiCoreCUPPO.Application.Services.Security;
using ApiCoreCUPPO.Application.Services.Venue;
using ApiCoreCUPPO.Infrastructure.Data;
using ApiCoreCUPPO.Infrastructure.Repositories.Catalog;
using ApiCoreCUPPO.Infrastructure.Repositories.Security;
using ApiCoreCUPPO.Infrastructure.Repositories.Venue;
using ApiCoreCUPPO.Infrastructure.Utilities.Authentication;
using ApiCoreCUPPO.Infrastructure.Utilities.Email;
using ApiCoreCUPPO.Infrastructure.Utilities.Storage;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Options;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Diagnostics;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.IdentityModel.Tokens;
using Microsoft.OpenApi;
using Scalar.AspNetCore;
using System.Globalization;
using System.Text;
using System.Threading.RateLimiting;

// ======================================================
// 0. Configuración Global de Cultura
// ======================================================
CultureInfo.DefaultThreadCurrentCulture = CultureInfo.InvariantCulture;
CultureInfo.DefaultThreadCurrentUICulture = CultureInfo.InvariantCulture;

var builder = WebApplication.CreateBuilder(args);

// ======================================================
// 1. Inyección de Dependencias
// ======================================================
builder.Services.Configure<JwtOptions>(builder.Configuration.GetSection("JwtOptions"));
builder.Services.Configure<SmtpOptions>(builder.Configuration.GetSection("Smtp"));

builder.Services.AddSingleton<IDbConnectionFactory, SqlConnectionFactory>();
builder.Services.AddSingleton<IJwtProvider, JwtProvider>();
builder.Services.AddSingleton<IPasswordHasher, BcryptPasswordHasher>();

// Correo: SMTP si está configurado; si no, se escribe en el log (en desarrollo, con el contenido)
if (builder.Configuration.GetSection("Smtp").Get<SmtpOptions>()?.IsConfigured == true)
    builder.Services.AddSingleton<IEmailSender, SmtpEmailSender>();
else
    builder.Services.AddSingleton<IEmailSender, LoggingEmailSender>();

builder.Services.AddScoped<ISecurityRepository, SecurityRepository>();
builder.Services.AddScoped<ISecurityService, SecurityService>();
builder.Services.AddScoped<IAuthService, AuthService>();

builder.Services.AddScoped<ICatalogRepository, CatalogRepository>();
builder.Services.AddScoped<ICatalogService, CatalogService>();

builder.Services.AddScoped<IOwnerRepository, OwnerRepository>();
builder.Services.AddScoped<IOwnerService, OwnerService>();

builder.Services.AddScoped<IVenueRepository, VenueRepository>();
builder.Services.AddScoped<IVenueManagementService, VenueManagementService>();
builder.Services.AddScoped<ICourtRepository, CourtRepository>();
builder.Services.AddScoped<ICourtManagementService, CourtManagementService>();
builder.Services.AddScoped<IPublicVenueRepository, PublicVenueRepository>();
builder.Services.AddScoped<IPublicVenueService, PublicVenueService>();

// Archivos: fotos públicas en /uploads y documentos privados (ver Storage:RootPath)
builder.Services.Configure<StorageOptions>(builder.Configuration.GetSection("Storage"));
builder.Services.AddSingleton<LocalFileStorage>(sp =>
    new LocalFileStorage(sp.GetRequiredService<IOptions<StorageOptions>>(), builder.Environment.ContentRootPath));
builder.Services.AddSingleton<IFileStorage>(sp => sp.GetRequiredService<LocalFileStorage>());

builder.Services.AddMemoryCache();
builder.Services.AddHttpClient();

// ======================================================
// 2. Configuración de CORS
// ======================================================
// La app móvil no necesita CORS; solo aplica a clientes web (panel Blazor, Scalar).
// En desarrollo se permite cualquier origen; en producción solo los de "Cors:AllowedOrigins".
var allowedOrigins = builder.Configuration.GetSection("Cors:AllowedOrigins").Get<string[]>() ?? [];

builder.Services.AddCors(options =>
{
    options.AddPolicy("DefaultPolicy", policy =>
    {
        if (builder.Environment.IsDevelopment())
            policy.AllowAnyOrigin();
        else
            policy.WithOrigins(allowedOrigins);

        policy.AllowAnyHeader()
              .AllowAnyMethod()
              .WithExposedHeaders("Content-Disposition");
    });
});

// ======================================================
// 3. Autenticación con JWT Bearer
// ======================================================
// En desarrollo viene de User Secrets; en el servidor, de la variable de entorno JwtOptions__SecretKey.
var jwtSecretKey = builder.Configuration["JwtOptions:SecretKey"];
if (string.IsNullOrWhiteSpace(jwtSecretKey))
{
    var secretsId = typeof(Program).Assembly
        .GetCustomAttributes(typeof(Microsoft.Extensions.Configuration.UserSecrets.UserSecretsIdAttribute), false)
        .Cast<Microsoft.Extensions.Configuration.UserSecrets.UserSecretsIdAttribute>()
        .FirstOrDefault()?.UserSecretsId;
    var secretsPath = secretsId is null ? "(sin UserSecretsId)" : Microsoft.Extensions.Configuration.UserSecrets.PathHelper.GetSecretsPathFromSecretsId(secretsId);
    // Por cada fuente: si trae la clave y su longitud (nunca el valor)
    var providers = string.Join(" | ", ((IConfigurationRoot)builder.Configuration).Providers.Select(p =>
        p.TryGet("JwtOptions:SecretKey", out var v) ? $"{p} [clave: {v?.Length ?? 0} car.]" : $"{p} [sin clave]"));
    long secretsBytes = -1;
    try { if (File.Exists(secretsPath)) secretsBytes = File.ReadAllBytes(secretsPath).Length; } catch { secretsBytes = -2; }
    providers += $" | Bytes leídos de secrets.json: {secretsBytes}";

    throw new InvalidOperationException(
        $"La clave secreta JWT 'JwtOptions:SecretKey' no está configurada (entorno: {builder.Environment.EnvironmentName}). " +
        "En desarrollo use el perfil 'https' o 'http' y configure los User Secrets; en el servidor, la variable de entorno JwtOptions__SecretKey. " +
        $"Archivo de secretos esperado: {secretsPath} (existe: {File.Exists(secretsPath)}). Fuentes cargadas: {providers}");
}

builder.Services.AddAuthentication(options =>
{
    options.DefaultAuthenticateScheme = JwtBearerDefaults.AuthenticationScheme;
    options.DefaultChallengeScheme = JwtBearerDefaults.AuthenticationScheme;
})
.AddJwtBearer(options =>
{
    options.RequireHttpsMetadata = !builder.Environment.IsDevelopment();
    options.SaveToken = true;
    // Conserva los nombres originales de los claims ("sub", "email"...) para leerlos tal cual en los controladores.
    options.MapInboundClaims = false;
    options.TokenValidationParameters = new TokenValidationParameters
    {
        ValidateIssuerSigningKey = true,
        IssuerSigningKey = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(jwtSecretKey)),
        ValidateIssuer = true,
        ValidIssuer = builder.Configuration["JwtOptions:Issuer"],
        ValidateAudience = true,
        ValidAudience = builder.Configuration["JwtOptions:Audience"],
        ValidateLifetime = true,
        ClockSkew = TimeSpan.Zero,
        NameClaimType = "sub",
        RoleClaimType = JwtProvider.RoleClaim
    };
});

builder.Services.AddAuthorization(options =>
{
    options.AddPolicy(Policies.SuperAdmin, policy => policy.RequireRole(Roles.SuperAdmin));
    options.AddPolicy(Policies.VerifiedOwner, policy => policy.RequireRole(Roles.ComplexAdmin));
});

// Límite por IP en login, registro y recuperación de contraseña. Es amplio porque muchos usuarios
// móviles comparten IP (CGNAT); el bloqueo tras 5 intentos fallidos protege cada cuenta.
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy(RateLimitPolicies.Auth, httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions { PermitLimit = 20, Window = TimeSpan.FromMinutes(1) }));
    options.OnRejected = async (context, cancellationToken) =>
        await context.HttpContext.Response.WriteAsJsonAsync(
            new { code = -429, message = "Demasiados intentos. Espera un minuto e inténtalo de nuevo." }, cancellationToken);
});

// ======================================================
// 4. Controladores y OpenAPI / Scalar con JWT
// ======================================================
builder.Services.AddControllers();

builder.Services.AddOpenApi(options =>
{
    options.AddDocumentTransformer((document, context, cancellationToken) =>
    {
        var securityScheme = new OpenApiSecurityScheme
        {
            Name = "Authorization",
            Description = "Ingresa el token JWT en el formato: Bearer {tu_token}",
            In = ParameterLocation.Header,
            Type = SecuritySchemeType.Http,
            Scheme = "bearer",
            BearerFormat = "JWT"
        };

        document.Components ??= new OpenApiComponents();
        document.Components.SecuritySchemes ??= new Dictionary<string, IOpenApiSecurityScheme>();
        document.Components.SecuritySchemes["Bearer"] = securityScheme;

        var schemeReference = new OpenApiSecuritySchemeReference("Bearer", document);
        var requirement = new OpenApiSecurityRequirement
        {
            [schemeReference] = new List<string>()
        };

        document.Security ??= new List<OpenApiSecurityRequirement>();
        document.Security.Add(requirement);

        return Task.CompletedTask;
    });
});

// ======================================================
// 5. Construcción y Pipeline HTTP
// ======================================================
var app = builder.Build();

if (!app.Environment.IsDevelopment())
{
    // Errores no controlados: se registran en el log y el cliente recibe un mensaje genérico
    app.UseExceptionHandler(errorApp => errorApp.Run(async context =>
    {
        var error = context.Features.Get<IExceptionHandlerFeature>()?.Error;
        app.Logger.LogError(error, "Error no controlado en {Path}", context.Request.Path);

        context.Response.StatusCode = error is UnauthorizedAccessException ? StatusCodes.Status401Unauthorized : StatusCodes.Status500InternalServerError;
        await context.Response.WriteAsJsonAsync(new { code = -1, message = "Ocurrió un error inesperado. Intenta de nuevo." });
    }));
    app.UseHsts();
}

app.UseCors("DefaultPolicy");
app.UseHttpsRedirection();

// Fotos públicas (complejos y canchas). Los documentos privados no se publican.
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(app.Services.GetRequiredService<LocalFileStorage>().PublicRoot),
    RequestPath = StorageOptions.PublicRequestPath
});

if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.MapScalarApiReference(options =>
    {
        options
            .WithTitle("CUPPO API - Core Engine")
            .WithTheme(ScalarTheme.Moon)
            .WithDefaultHttpClient(ScalarTarget.CSharp, ScalarClient.HttpClient);
    });
}

app.UseAuthentication();
app.UseAuthorization();
app.UseRateLimiter();

app.MapControllers();
app.MapGet("/", () => Results.Redirect("/scalar/v1"));

app.Run();
