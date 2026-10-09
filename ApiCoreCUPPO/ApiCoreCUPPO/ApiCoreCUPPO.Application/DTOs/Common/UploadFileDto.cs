namespace ApiCoreCUPPO.Application.DTOs.Common
{
    /// <summary>Archivo recibido por la API, sin depender de ASP.NET (IFormFile).</summary>
    public record UploadFileDto(Stream Content, long Length, string FileName);
}
