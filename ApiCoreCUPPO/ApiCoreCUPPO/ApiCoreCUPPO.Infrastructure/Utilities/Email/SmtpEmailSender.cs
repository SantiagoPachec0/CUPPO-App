using ApiCoreCUPPO.Application.Interfaces.IServices.Common;
using Microsoft.Extensions.Options;
using System.Net;
using System.Net.Mail;

namespace ApiCoreCUPPO.Infrastructure.Utilities.Email
{
    public class SmtpEmailSender : IEmailSender
    {
        private readonly SmtpOptions _options;

        public SmtpEmailSender(IOptions<SmtpOptions> options)
        {
            _options = options.Value;
        }

        public async Task SendAsync(string to, string subject, string body, CancellationToken cancellationToken = default)
        {
            using var message = new MailMessage
            {
                From = new MailAddress(_options.FromAddress, _options.FromName),
                Subject = subject,
                Body = body
            };
            message.To.Add(to);

            using var client = new SmtpClient(_options.Host, _options.Port)
            {
                EnableSsl = _options.EnableSsl,
                Credentials = string.IsNullOrWhiteSpace(_options.User) ? null : new NetworkCredential(_options.User, _options.Password)
            };

            await client.SendMailAsync(message, cancellationToken);
        }
    }
}
