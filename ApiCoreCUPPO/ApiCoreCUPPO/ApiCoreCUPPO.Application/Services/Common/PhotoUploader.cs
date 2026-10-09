using ApiCoreCUPPO.Application.DTOs.Common;
using ApiCoreCUPPO.Application.Interfaces.IServices.Common;

namespace ApiCoreCUPPO.Application.Services.Common
{
    /// <summary>
    /// Flujo común para subir una foto: valida la imagen, la guarda y la registra en la base.
    /// Si la base rechaza la operación (sin permiso, límite de fotos), borra el archivo guardado.
    /// </summary>
    public static class PhotoUploader
    {
        public static async Task<SpResultDto> UploadAsync(
            IFileStorage storage, UploadFileDto file, string folder, bool isPrivate,
            Func<string, Task<SpResultDto>> register)
        {
            var (extension, error) = ImageValidator.Validate(file.Content, file.Length);
            if (extension is null)
                return new SpResultDto { CodeResult = -400, MessageResult = error! };

            var url = isPrivate
                ? await storage.SavePrivateAsync(file.Content, folder, extension)
                : await storage.SavePublicAsync(file.Content, folder, extension);

            SpResultDto result;
            try
            {
                result = await register(url);
            }
            catch
            {
                await storage.DeleteAsync(url);
                throw;
            }

            if (!result.IsSuccess)
                await storage.DeleteAsync(url);

            return result;
        }
    }
}
