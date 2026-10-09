using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;

namespace ApiCoreCUPPO.Infrastructure.Utilities.Email
{
    /// <summary>
    /// Se usa cuando no hay SMTP configurado. En desarrollo escribe el correo completo en la
    /// consola (para ver los códigos de recuperación); en otros entornos solo avisa, sin el contenido.
    /// </summary>
    public class LoggingEmailSender : IEmailSender
    {
        private readonly ILogger<LoggingEmailSender> _logger;
        private readonly IHostEnvironment _environment;

        public LoggingEmailSender(ILogger<LoggingEmailSender> logger, IHostEnvironment environment)
        {
            _logger = logger;
            _environment = environment;
        }

        public Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default)
        {
            if (_environment.IsDevelopment())
                _logger.LogWarning("[CORREO DE DESARROLLO] Para: {To} | Asunto: {Subject}{NewLine}{Body}", to, subject, Environment.NewLine, body);
            else
                _logger.LogError("No hay SMTP configurado: no se pudo enviar el correo '{Subject}' a {To}.", subject, to);

            return Task.CompletedTask;
        }
    }
}
