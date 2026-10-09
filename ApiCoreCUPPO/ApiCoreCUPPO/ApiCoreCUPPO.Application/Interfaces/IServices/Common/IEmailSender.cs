namespace ApiCoreCUPPO.Application.Interfaces.IServices.Common
{
    public interface IEmailSender
    {
        Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default);
    }
}
