namespace ApiCoreCUPPO.Application.Services.Common
{
    /// <summary>
    /// Valida imágenes por su contenido real (firma de bytes), no por la extensión ni el
    /// Content-Type que manda el cliente.
    /// </summary>
    public static class ImageValidator
    {
        public const long MaxBytes = 5 * 1024 * 1024;

        /// <summary>Devuelve la extensión (".jpg", ".png", ".webp") o un mensaje de error.</summary>
        public static (string? Extension, string? Error) Validate(Stream content, long length)
        {
            if (length <= 0)
                return (null, "El archivo está vacío.");

            if (length > MaxBytes)
                return (null, "La imagen supera el máximo de 5 MB.");

            Span<byte> header = stackalloc byte[12];
            var read = content.Read(header);
            if (content.CanSeek)
                content.Position = 0;

            if (read >= 3 && header[0] == 0xFF && header[1] == 0xD8 && header[2] == 0xFF)
                return (".jpg", null);

            if (read >= 8 && header[..8].SequenceEqual(new byte[] { 0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A }))
                return (".png", null);

            if (read >= 12 && header[..4].SequenceEqual("RIFF"u8) && header[8..12].SequenceEqual("WEBP"u8))
                return (".webp", null);

            return (null, "Formato no permitido. Usa JPG, PNG o WEBP.");
        }
    }
}
