using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using SmartParking.API.Security;
using SmartParking.Domain.Entities;
using SmartParking.Infrastructure.Persistence;

namespace SmartParking.API.Controllers;

[ApiController]
[Route("api/favorites")]
[Authorize]
public sealed class FavoritesController : ControllerBase
{
    private readonly ApplicationDbContext _context;

    public FavoritesController(ApplicationDbContext context) => _context = context;

    [HttpGet]
    public async Task<IActionResult> GetMine(CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var favorites = await _context.Favorites
            .AsNoTracking()
            .Include(item => item.ParkingLot)
            .Where(item => item.UserId == userId && !item.IsDeleted && item.ParkingLot.IsActive)
            .OrderBy(item => item.ParkingLot.Name)
            .Select(item => new
            {
                item.Id,
                item.ParkingLotId,
                item.ParkingLot.Name,
                item.ParkingLot.Address,
                item.ParkingLot.Zone,
                item.ParkingLot.AvailableCapacity,
                item.CreatedAt
            })
            .ToListAsync(cancellationToken);
        return Ok(favorites);
    }

    [HttpPost("{parkingLotId:guid}")]
    public async Task<IActionResult> Add(Guid parkingLotId, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        if (!await _context.ParkingLots.AnyAsync(
            item => item.Id == parkingLotId && item.IsActive,
            cancellationToken))
        {
            return NotFound(new { message = "Otopark bulunamadı." });
        }

        var existing = await _context.Favorites.FirstOrDefaultAsync(
            item => item.UserId == userId && item.ParkingLotId == parkingLotId,
            cancellationToken);
        if (existing is not null)
        {
            existing.IsDeleted = false;
            existing.UpdatedAt = DateTime.UtcNow;
            await _context.SaveChangesAsync(cancellationToken);
            return Ok(existing);
        }

        var favorite = new Favorite { UserId = userId, ParkingLotId = parkingLotId };
        _context.Favorites.Add(favorite);
        await _context.SaveChangesAsync(cancellationToken);
        return CreatedAtAction(nameof(GetMine), new { }, favorite);
    }

    [HttpDelete("{parkingLotId:guid}")]
    public async Task<IActionResult> Remove(Guid parkingLotId, CancellationToken cancellationToken)
    {
        var userId = User.GetUserId();
        var favorite = await _context.Favorites.FirstOrDefaultAsync(
            item => item.UserId == userId && item.ParkingLotId == parkingLotId && !item.IsDeleted,
            cancellationToken);
        if (favorite is null)
            return NoContent();
        favorite.IsDeleted = true;
        favorite.UpdatedAt = DateTime.UtcNow;
        await _context.SaveChangesAsync(cancellationToken);
        return NoContent();
    }
}
