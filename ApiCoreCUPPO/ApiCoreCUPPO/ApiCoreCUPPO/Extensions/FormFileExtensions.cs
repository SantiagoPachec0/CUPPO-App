using ApiCoreCUPPO.Application.DTOs.Common;

namespace ApiCoreCUPPO.API.Extensions
{
    public static class UploadLimits
    {
        /// <summary>Tamaño máximo de la petición de subida (la imagen en sí está limitada a 5 MB).</summary>
        public const long MaxRequestBytes = 6 * 1024 * 1024;
    }

    public static class FormFileExtensions
    {
        public static UploadFileDto ToUploadDto(this IFormFile file, Stream stream)
            => new(stream, file.Length, file.FileName);
    }
}
