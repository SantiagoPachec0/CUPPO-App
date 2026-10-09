namespace ApiCoreCUPPO.Application.Interfaces.IServices.Common
{
    public interface IFileStorage
    {
        /// <summary>Guarda un archivo visible para todos (fotos). Devuelve la URL relativa, ej. "/uploads/venues/abc.jpg".</summary>
        Task<string> SavePublicAsync(Stream content, string folder, string extension, CancellationToken cancellationToken = default);

        /// <summary>Guarda un archivo privado (documentos). Devuelve la clave interna para leerlo después.</summary>
        Task<string> SavePrivateAsync(Stream content, string folder, string extension, CancellationToken cancellationToken = default);

        /// <summary>Abre un archivo privado; null si no existe.</summary>
        Stream? OpenPrivate(string key);

        /// <summary>Borra un archivo público (por URL) o privado (por clave). No falla si no existe.</summary>
        Task DeleteAsync(string urlOrKey);
    }
}
