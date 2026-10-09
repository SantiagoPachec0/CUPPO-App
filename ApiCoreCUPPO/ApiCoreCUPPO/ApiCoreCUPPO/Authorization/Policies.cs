namespace ApiCoreCUPPO.API.Authorization
{
    /// <summary>Políticas de autorización basadas en los roles del token.</summary>
    public static class Policies
    {
        /// <summary>Administrador de CUPPO.</summary>
        public const string SuperAdmin = "SuperAdmin";

        /// <summary>Dueño de complejo verificado (el rol solo llega al token si CUPPO lo aprobó).</summary>
        public const string VerifiedOwner = "VerifiedOwner";
    }

    public static class Roles
    {
        public const string SuperAdmin = "SUPERADMIN";
        public const string ComplexAdmin = "COMPLEX_ADMIN";
        public const string Client = "CLIENT";
    }

    public static class RateLimitPolicies
    {
        /// <summary>Login, registro y recuperación de contraseña: 20 peticiones por minuto por IP.</summary>
        public const string Auth = "auth";
    }
}
