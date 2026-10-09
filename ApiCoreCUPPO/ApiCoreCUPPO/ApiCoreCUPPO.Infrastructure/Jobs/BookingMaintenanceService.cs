using ApiCoreCUPPO.Application.Interfaces.IRepository.Booking;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;

namespace ApiCoreCUPPO.Infrastructure.Jobs
{
    public class JobsOptions
    {
        /// <summary>Permite apagar los procesos automáticos (por ejemplo, si hay varias instancias de la API).</summary>
        public bool Enabled { get; set; } = true;

        /// <summary>Cada cuánto se liberan las reservas que no se pagaron a tiempo.</summary>
        public int ExpireBookingsSeconds { get; set; } = 60;

        /// <summary>Cada cuánto se marcan como completadas las reservas confirmadas que ya terminaron.</summary>
        public int CompleteBookingsMinutes { get; set; } = 15;
    }

    /// <summary>
    /// Procesos automáticos de reservas:
    /// - vence las reservas PENDING_PAYMENT cuyo tiempo para pagar terminó (libera la cancha);
    /// - marca como COMPLETED las reservas confirmadas que ya pasaron.
    /// </summary>
    public class BookingMaintenanceService : BackgroundService
    {
        private readonly IServiceScopeFactory _scopeFactory;
        private readonly ILogger<BookingMaintenanceService> _logger;
        private readonly JobsOptions _options;

        public BookingMaintenanceService(IServiceScopeFactory scopeFactory, ILogger<BookingMaintenanceService> logger, IOptions<JobsOptions> options)
        {
            _scopeFactory = scopeFactory;
            _logger = logger;
            _options = options.Value;
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            if (!_options.Enabled)
            {
                _logger.LogInformation("Procesos automáticos de reservas desactivados (Jobs:Enabled = false).");
                return;
            }

            var expireEvery = TimeSpan.FromSeconds(Math.Max(10, _options.ExpireBookingsSeconds));
            var completeEvery = TimeSpan.FromMinutes(Math.Max(1, _options.CompleteBookingsMinutes));
            var lastComplete = DateTime.MinValue;

            using var timer = new PeriodicTimer(expireEvery);
            do
            {
                await RunAsync("ExpirePendingBookings", repo => repo.ExpirePendingBookingsAsync());

                if (DateTime.UtcNow - lastComplete >= completeEvery)
                {
                    await RunAsync("CompletePastBookings", repo => repo.CompletePastBookingsAsync());
                    lastComplete = DateTime.UtcNow;
                }
            }
            while (await timer.WaitForNextTickAsync(stoppingToken));
        }

        private async Task RunAsync(string name, Func<IBookingRepository, Task<ApiCoreCUPPO.Application.DTOs.Common.SpResultDto>> action)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var repository = scope.ServiceProvider.GetRequiredService<IBookingRepository>();
                var result = await action(repository);

                if (result.CodeResult > 0)
                    _logger.LogInformation("{Job}: {Message}", name, result.MessageResult);
                else if (result.CodeResult < 0)
                    _logger.LogError("{Job} falló: {Message}", name, result.MessageResult);
            }
            catch (Exception ex)
            {
                // Un fallo (ej. la base no responde) no detiene el servicio: se reintenta en el siguiente ciclo
                _logger.LogError(ex, "{Job} falló.", name);
            }
        }
    }
}
