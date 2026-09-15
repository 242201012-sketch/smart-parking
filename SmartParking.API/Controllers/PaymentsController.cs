using System.Net;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Security;
using SmartParking.Application.Interfaces;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Identity;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/payments")]
public sealed class PaymentsController : ControllerBase
{
    private readonly ApplicationDbContext _context;
    private readonly IConfiguration _configuration;
    private readonly IPushNotificationService _pushNotifications;
    private readonly ICardPaymentService _cardPayments;
    private readonly UserManager<AppUser> _userManager;

    public PaymentsController(
        ApplicationDbContext context,
        IConfiguration configuration,
        IPushNotificationService pushNotifications,
        ICardPaymentService cardPayments,
        UserManager<AppUser> userManager)
    {
        _context = context;
        _configuration = configuration;
        _pushNotifications = pushNotifications;
        _cardPayments = cardPayments;
        _userManager = userManager;
    }

    [HttpGet("config")]
    [AllowAnonymous]
    public IActionResult GetConfig()
    {
        var provider = _configuration["Payment:Provider"] ?? "disabled";
        return Ok(new
        {
            provider,
            enabled = provider.Equals("manual", StringComparison.OrdinalIgnoreCase)
                || _cardPayments.IsEnabled,
            supportedProviders = new[] { "manual", "iyzico" },
            supportedMethods = new[] { "virtual_pos", "qr" },
            currency = "TRY",
            hostedCheckout = provider.Equals("iyzico", StringComparison.OrdinalIgnoreCase),
            virtualPos = provider.Equals("iyzico", StringComparison.OrdinalIgnoreCase),
            qrPayment = provider.Equals("iyzico", StringComparison.OrdinalIgnoreCase),
            offlinePaymentsSupported = false,
            sandbox = _cardPayments.IsSandbox
        });
    }

    [HttpGet("payable-sessions")]
    [Authorize]
    public async Task<IActionResult> GetPayableSessions(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var sessions = await _context.ParkingSessions.AsNoTracking()
            .Include(item => item.ParkingLot)
            .Where(item =>
                item.UserId == userId
                && !item.IsDeleted
                && item.EndedAt != null
                && item.TotalAmount != null
                && item.PaymentStatus != "paid"
                && !_context.PaymentRecords.Any(payment =>
                    payment.ParkingSessionId == item.Id
                    && payment.Status == "paid"
                    && !payment.IsDeleted))
            .OrderByDescending(item => item.EndedAt)
            .Take(50)
            .Select(item => new
            {
                item.Id,
                ParkingLotName = item.ParkingLot.Name,
                item.VehiclePlate,
                item.EndedAt,
                item.TotalAmount,
                item.PaymentStatus
            })
            .ToListAsync(cancellationToken);
        return Ok(sessions);
    }

    [HttpGet]
    [Authorize]
    public async Task<IActionResult> GetMine(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var payments = await _context.PaymentRecords.AsNoTracking()
            .Where(item => item.UserId == userId && !item.IsDeleted)
            .OrderByDescending(item => item.CreatedAt)
            .Take(100)
            .ToListAsync(cancellationToken);
        return Ok(payments.Select(ToResponse));
    }

    [HttpGet("{id:guid}/status")]
    [Authorize]
    public async Task<IActionResult> GetStatus(Guid id, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var payment = await _context.PaymentRecords.AsNoTracking()
            .FirstOrDefaultAsync(
                item => item.Id == id && item.UserId == userId && !item.IsDeleted,
                cancellationToken);
        return payment is null ? NotFound() : Ok(ToResponse(payment));
    }

    [HttpPost("checkout")]
    [Authorize]
    [EnableRateLimiting("payment")]
    public async Task<IActionResult> CreateCheckout(
        [FromBody] CreateCardCheckoutRequest request,
        CancellationToken cancellationToken)
    {
        if (!_cardPayments.IsEnabled)
        {
            return StatusCode(StatusCodes.Status503ServiceUnavailable, new
            {
                message = "iyzico sandbox anahtarları ve herkese açık HTTPS callback adresi yapılandırılmalıdır."
            });
        }
        if (!IsValidBuyer(request, out var validationMessage))
            return BadRequest(new { message = validationMessage });

        var userId = User.GetUserId();
        var user = await _userManager.FindByIdAsync(userId.ToString());
        if (user is null || string.IsNullOrWhiteSpace(user.Email))
            return Unauthorized(new { message = "Kullanıcı hesabı bulunamadı." });

        var session = await _context.ParkingSessions
            .Include(item => item.ParkingLot)
            .FirstOrDefaultAsync(
                item => item.Id == request.ParkingSessionId
                    && item.UserId == userId
                    && !item.IsDeleted,
                cancellationToken);
        if (session is null || session.EndedAt is null || session.TotalAmount is null)
            return BadRequest(new { message = "Tamamlanmış bir park oturumu gereklidir." });
        if (session.TotalAmount <= 0)
            return BadRequest(new { message = "Ödenecek tutar geçersizdir." });
        if (session.PaymentStatus == "paid" || await _context.PaymentRecords.AnyAsync(
            item => item.ParkingSessionId == session.Id
                && item.Status == "paid"
                && !item.IsDeleted,
            cancellationToken))
        {
            return Conflict(new { message = "Bu oturum zaten ödendi." });
        }

        var stalePayments = await _context.PaymentRecords
            .Where(item => item.ParkingSessionId == session.Id
                && (item.Status == "pending" || item.Status == "checkout_ready"))
            .ToListAsync(cancellationToken);
        foreach (var stale in stalePayments)
        {
            stale.Status = "abandoned";
            stale.UpdatedAt = DateTime.UtcNow;
        }

        var payment = new PaymentRecord
        {
            UserId = userId,
            ParkingSession = session,
            ParkingSessionId = session.Id,
            Provider = _cardPayments.Provider,
            Amount = session.TotalAmount.Value,
            Currency = "TRY",
            Status = "pending"
        };
        payment.ProviderConversationId = payment.Id.ToString("N");
        _context.PaymentRecords.Add(payment);
        await _context.SaveChangesAsync(cancellationToken);

        var nameParts = (user.FullName ?? string.Empty)
            .Split(' ', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        var firstName = nameParts.FirstOrDefault() ?? "SmartParking";
        var lastName = nameParts.Length > 1
            ? string.Join(' ', nameParts.Skip(1))
            : "Kullanıcısı";
        var checkout = await _cardPayments.InitializeCheckoutAsync(
            new CardCheckoutRequest(
                payment.ProviderConversationId,
                payment.Amount,
                userId.ToString("N"),
                firstName,
                lastName,
                user.Email!,
                NormalizePhone(request.GsmNumber),
                request.IdentityNumber!.Trim(),
                request.RegistrationAddress!.Trim(),
                request.City!.Trim(),
                request.Country!.Trim(),
                request.ZipCode!.Trim(),
                HttpContext.Connection.RemoteIpAddress?.ToString() ?? "127.0.0.1",
                session.Id.ToString("N"),
                $"{session.ParkingLot.Name} park hizmeti"),
            cancellationToken);

        if (!checkout.Success || string.IsNullOrWhiteSpace(checkout.Token)
            || string.IsNullOrWhiteSpace(checkout.PaymentPageUrl))
        {
            payment.Status = "initialization_failed";
            payment.FailureReason = Limit(checkout.ErrorMessage ?? "Ödeme sayfası başlatılamadı.", 500);
            payment.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            return StatusCode(StatusCodes.Status502BadGateway, new
            {
                message = "iyzico ödeme sayfası başlatılamadı.",
                detail = payment.FailureReason
            });
        }

        payment.ProviderToken = checkout.Token;
        payment.Status = "checkout_ready";
        payment.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        return Ok(new
        {
            paymentId = payment.Id,
            checkoutUrl = checkout.PaymentPageUrl,
            qrPayload = checkout.PaymentPageUrl,
            supportedMethods = new[] { "virtual_pos", "qr" },
            provider = payment.Provider,
            sandbox = _cardPayments.IsSandbox
        });
    }

    [HttpPost("iyzico/callback")]
    [AllowAnonymous]
    [IgnoreAntiforgeryToken]
    [EnableRateLimiting("payment-callback")]
    public async Task<IActionResult> IyzicoCallback(
        [FromForm] string? token,
        CancellationToken cancellationToken)
    {
        Response.Headers["Cache-Control"] = "no-store";
        Response.Headers["Content-Security-Policy"] = "default-src 'none'; style-src 'unsafe-inline'";
        if (string.IsNullOrWhiteSpace(token) || token.Length > 256)
            return PaymentResultPage(null, "failed", "Geçersiz ödeme dönüşü.");

        var payment = await _context.PaymentRecords
            .Include(item => item.ParkingSession)
            .OrderByDescending(item => item.CreatedAt)
            .FirstOrDefaultAsync(
                item => item.Provider == "iyzico"
                    && item.ProviderToken == token
                    && !item.IsDeleted,
                cancellationToken);
        if (payment is null || string.IsNullOrWhiteSpace(payment.ProviderConversationId))
            return PaymentResultPage(null, "failed", "Ödeme kaydı bulunamadı.");
        if (payment.Status == "paid")
            return PaymentResultPage(payment.Id, "paid", "Ödeme daha önce onaylandı.");

        CardPaymentResult result;
        try
        {
            result = await _cardPayments.RetrieveAsync(
                payment.ProviderConversationId,
                token,
                cancellationToken);
        }
        catch
        {
            payment.Status = "verification_failed";
            payment.FailureReason = "Ödeme sağlayıcısından doğrulama sonucu alınamadı.";
            payment.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            return PaymentResultPage(payment.Id, "failed", "Ödeme doğrulanamadı; hesabınızdan çekim olduysa destekle iletişime geçin.");
        }

        var identityMatches = result.ConversationId == payment.ProviderConversationId
            && result.Token == payment.ProviderToken;
        var amountMatches = Math.Abs(result.PaidPrice - payment.Amount) < 0.01m;
        var providerApproved = result.RequestSucceeded
            && result.PaymentStatus.Equals("SUCCESS", StringComparison.OrdinalIgnoreCase);

        if (!identityMatches || !amountMatches || !providerApproved)
        {
            payment.Status = "failed";
            payment.FailureReason = Limit(
                result.ErrorMessage ?? "Token, işlem kimliği, tutar veya ödeme durumu doğrulanamadı.",
                500);
        }
        else if (result.FraudStatus == 1)
        {
            payment.Status = "paid";
            payment.ProviderReference = Limit(result.PaymentId, 128);
            payment.PaidAt = DateTime.UtcNow;
            payment.FailureReason = null;
            payment.ParkingSession.PaymentStatus = "paid";
            payment.ParkingSession.UpdatedAt = DateTime.UtcNow;
        }
        else if (result.FraudStatus == 0)
        {
            payment.Status = "review";
            payment.ProviderReference = Limit(result.PaymentId, 128);
            payment.FailureReason = "iyzico fraud kontrolü sonuçlanmadı.";
        }
        else
        {
            payment.Status = "failed";
            payment.FailureReason = "iyzico işlemi riskli olarak değerlendirdi.";
        }

        payment.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        if (payment.Status == "paid")
        {
            await _pushNotifications.SendToUserAsync(
                payment.UserId,
                "Ödeme onaylandı",
                $"{payment.Amount:0.00} {payment.Currency} tutarındaki ödemeniz onaylandı.",
                new Dictionary<string, string> { ["screen"] = "profile" },
                cancellationToken);
            return PaymentResultPage(payment.Id, "paid", "Ödemeniz başarıyla onaylandı.");
        }
        if (payment.Status == "review")
            return PaymentResultPage(payment.Id, "review", "Ödemeniz güvenlik incelemesinde.");
        return PaymentResultPage(payment.Id, "failed", "Ödeme onaylanmadı.");
    }

    [HttpPost]
    [Authorize]
    public async Task<IActionResult> CreateManual(
        [FromBody] CreatePaymentRequest request,
        CancellationToken cancellationToken)
    {
        var provider = (_configuration["Payment:Provider"] ?? "disabled").ToLowerInvariant();
        if (provider != "manual")
            return BadRequest(new { message = "Manuel ödeme sağlayıcısı etkin değil." });

        var userId = User.GetUserId();
        var session = await _context.ParkingSessions.FirstOrDefaultAsync(
            item => item.Id == request.ParkingSessionId && item.UserId == userId,
            cancellationToken);
        if (session is null || session.EndedAt is null || session.TotalAmount is null)
            return BadRequest(new { message = "Tamamlanmış bir park oturumu gereklidir." });
        if (await _context.PaymentRecords.AnyAsync(
            item => item.ParkingSessionId == session.Id && item.Status == "paid",
            cancellationToken))
        {
            return Conflict(new { message = "Bu oturum zaten ödendi." });
        }

        var payment = new PaymentRecord
        {
            UserId = userId,
            ParkingSession = session,
            ParkingSessionId = session.Id,
            Provider = "manual",
            Amount = session.TotalAmount.Value,
            Currency = "TRY",
            Status = "awaiting_confirmation"
        };
        _context.PaymentRecords.Add(payment);
        await _context.SaveChangesAsync(cancellationToken);
        return Accepted(ToResponse(payment));
    }

    [HttpPost("{id:guid}/confirm")]
    [Authorize(Roles = "Admin")]
    public async Task<IActionResult> ConfirmManual(Guid id, CancellationToken cancellationToken)
    {
        var payment = await _context.PaymentRecords
            .Include(item => item.ParkingSession)
            .FirstOrDefaultAsync(item => item.Id == id, cancellationToken);
        if (payment is null)
            return NotFound();
        if (payment.Provider != "manual")
            return BadRequest(new { message = "Yalnızca manuel ödemeler bu uçtan onaylanabilir." });

        payment.Status = "paid";
        payment.ProviderReference = $"MANUAL-{DateTime.UtcNow:yyyyMMddHHmmss}";
        payment.PaidAt = DateTime.UtcNow;
        payment.UpdatedAt = DateTime.UtcNow;
        payment.ParkingSession.PaymentStatus = "paid";
        payment.ParkingSession.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        await _pushNotifications.SendToUserAsync(
            payment.UserId,
            "Ödeme onaylandı",
            $"{payment.Amount:0.00} {payment.Currency} tutarındaki ödemeniz onaylandı.",
            new Dictionary<string, string> { ["screen"] = "profile" },
            cancellationToken);
        return Ok(ToResponse(payment));
    }

    private IActionResult PaymentResultPage(Guid? paymentId, string status, string message)
    {
        var configuredScheme = _configuration["Payment:ReturnScheme"];
        var returnUri = Uri.TryCreate(configuredScheme, UriKind.Absolute, out var candidate)
            && candidate.Scheme == "smartparking"
            && candidate.Host == "payment-result"
                ? candidate
                : new Uri("smartparking://payment-result");
        var query = $"paymentId={Uri.EscapeDataString(paymentId?.ToString() ?? string.Empty)}"
            + $"&status={Uri.EscapeDataString(status)}";
        var separator = string.IsNullOrEmpty(returnUri.Query) ? "?" : "&";
        var link = WebUtility.HtmlEncode($"{returnUri}{separator}{query}");
        var safeMessage = WebUtility.HtmlEncode(message);
        var safeStatus = WebUtility.HtmlEncode(status);
        var html = $@"<!doctype html><html lang=""tr""><head><meta charset=""utf-8"">
            <meta name=""viewport"" content=""width=device-width,initial-scale=1"">
            <title>SmartParking ödeme</title><style>
            body{{font-family:system-ui;background:#f3f7f5;color:#17332e;display:grid;place-items:center;min-height:100vh;margin:0}}
            main{{background:white;padding:32px;border-radius:24px;max-width:430px;box-shadow:0 12px 36px #17332e22;text-align:center}}
            a{{display:inline-block;background:#105c4e;color:white;padding:13px 20px;border-radius:14px;text-decoration:none;font-weight:700}}
            </style></head><body><main><h1>Ödeme: {safeStatus}</h1><p>{safeMessage}</p>
            <p><a href=""{link}"">SmartParking'e dön</a></p></main></body></html>";
        return Content(html, "text/html; charset=utf-8");
    }

    private static bool IsValidBuyer(
        CreateCardCheckoutRequest request,
        out string validationMessage)
    {
        if (string.IsNullOrWhiteSpace(request.IdentityNumber)
            || request.IdentityNumber.Length != 11
            || !request.IdentityNumber.All(char.IsDigit))
        {
            validationMessage = "T.C. kimlik numarası 11 haneli olmalıdır.";
            return false;
        }
        var phone = NormalizePhone(request.GsmNumber);
        var phoneDigits = phone.TrimStart('+');
        if (phoneDigits.Length is < 10 or > 15 || !phoneDigits.All(char.IsDigit))
        {
            validationMessage = "Geçerli bir telefon numarası gereklidir.";
            return false;
        }
        if (string.IsNullOrWhiteSpace(request.RegistrationAddress)
            || request.RegistrationAddress.Trim().Length is < 5 or > 300
            || string.IsNullOrWhiteSpace(request.City)
            || request.City.Trim().Length is < 2 or > 100
            || string.IsNullOrWhiteSpace(request.Country)
            || request.Country.Trim().Length is < 2 or > 100
            || string.IsNullOrWhiteSpace(request.ZipCode)
            || request.ZipCode.Trim().Length is < 3 or > 12)
        {
            validationMessage = "Geçerli fatura adresi, şehir, ülke ve posta kodu gereklidir.";
            return false;
        }
        validationMessage = string.Empty;
        return true;
    }

    private static string NormalizePhone(string? value) =>
        new((value ?? string.Empty).Where(character => char.IsDigit(character) || character == '+').ToArray());

    private static string Limit(string value, int maxLength) =>
        value.Length <= maxLength ? value : value[..maxLength];

    private static object ToResponse(PaymentRecord item) => new
    {
        item.Id,
        item.ParkingSessionId,
        item.Provider,
        item.Amount,
        item.Currency,
        item.Status,
        item.FailureReason,
        item.PaidAt,
        item.CreatedAt,
        item.UpdatedAt
    };
}

public sealed record CreatePaymentRequest(Guid ParkingSessionId);

public sealed record CreateCardCheckoutRequest(
    Guid ParkingSessionId,
    string? GsmNumber,
    string? IdentityNumber,
    string? RegistrationAddress,
    string? City,
    string? Country,
    string? ZipCode);
