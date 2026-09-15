using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using SmartParking.Application.Interfaces;
using SmartParking.Application.Parking.DTO;
using Microsoft.EntityFrameworkCore;
using SmartParking.Infrastructure.Persistence;
using System.Globalization;
using System.Text;

namespace SmartParking.API.Controllers
{
    [ApiController]
    [Route("api/[controller]")]
    public class ParkingController : ControllerBase
    {
        private readonly IParkingService _parkingService;
        private readonly ApplicationDbContext _context;

        public ParkingController(IParkingService parkingService, ApplicationDbContext context)
        {
            _parkingService = parkingService;
            _context = context;
        }

        [HttpGet]
        [AllowAnonymous]
        public async Task<ActionResult<IReadOnlyList<ParkingLocationDto>>> GetAll(
            string? zone = null,
            string? province = null,
            string? q = null,
            bool? electric = null,
            bool? accessible = null,
            bool? covered = null)
        {
            var results = await _parkingService.GetAllAsync();
            var requestedProvince = string.IsNullOrWhiteSpace(province) ? zone : province;
            var normalizedProvince = NormalizeForSearch(requestedProvince);
            var normalizedQuery = NormalizeForSearch(q);
            var filtered = results
                .Where(item => string.IsNullOrEmpty(normalizedProvince)
                    || NormalizeForSearch(item.Zone) == normalizedProvince)
                .Where(item => string.IsNullOrEmpty(normalizedQuery)
                    || NormalizeForSearch(item.Name).Contains(normalizedQuery, StringComparison.Ordinal)
                    || NormalizeForSearch(item.Address).Contains(normalizedQuery, StringComparison.Ordinal)
                    || NormalizeForSearch(item.Zone).Contains(normalizedQuery, StringComparison.Ordinal))
                .Where(item => electric is null || item.HasElectricCharging == electric)
                .Where(item => accessible is null || item.HasAccessibleSpaces == accessible)
                .Where(item => covered is null || item.IsCovered == covered)
                .ToList();
            return Ok(filtered);
        }

        [HttpGet("{id:guid}")]
        [AllowAnonymous]
        public async Task<ActionResult<ParkingLocationDto>> GetById(Guid id)
        {
            var parking = await _parkingService.GetByIdAsync(id);
            return parking is null ? NotFound() : Ok(parking);
        }

        // GET /api/parking/nearest?lat=40.65&lng=35.83
        [HttpGet("nearest")]
        [AllowAnonymous]
        public async Task<ActionResult<ParkingLocationDto>> GetNearest(double lat, double lng)
        {
            if (lat is < -90 or > 90 || lng is < -180 or > 180)
                return BadRequest("Geçerli bir enlem ve boylam gönderilmelidir.");

            var spot = await _parkingService.GetNearestAvailableAsync(lat, lng);

            if (spot == null)
                return NotFound("Uygun boş park yeri bulunamadı.");

            return Ok(spot);
        }

        [HttpGet("{id:guid}/spaces")]
        [AllowAnonymous]
        public async Task<IActionResult> GetSpaces(Guid id)
        {
            var now = DateTime.UtcNow;
            var spaces = await _context.ParkingSpaces
                .AsNoTracking()
                .Where(space => space.ParkingLotId == id)
                .OrderBy(space => space.Code)
                .Select(space => new
                {
                    space.Id,
                    space.Code,
                    space.IsOccupied,
                    IsReserved = space.IsReserved && space.ReservedUntil > now,
                    space.ReservedUntil,
                    space.IsElectric,
                    space.IsAccessible,
                    space.LastOccupiedAt,
                    space.UpdatedAt
                })
                .ToListAsync();
            return spaces.Count == 0 ? NotFound() : Ok(spaces);
        }

        private static string NormalizeForSearch(string? value)
        {
            if (string.IsNullOrWhiteSpace(value)) return string.Empty;

            var decomposed = value
                .Trim()
                .Replace('ı', 'i')
                .Replace('İ', 'I')
                .Normalize(NormalizationForm.FormD);
            var builder = new StringBuilder(decomposed.Length);
            foreach (var character in decomposed)
            {
                if (CharUnicodeInfo.GetUnicodeCategory(character) != UnicodeCategory.NonSpacingMark)
                    builder.Append(character);
            }

            return builder.ToString()
                .Normalize(NormalizationForm.FormC)
                .ToUpperInvariant();
        }
    }
}
