using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using SmartParking.Application.Authentication.Commands.Login;
using SmartParking.Application.Authentication.Commands.Register;
using SmartParking.Application.Authentication.Interfaces;
using SmartParking.Application.Authentication.Response;

namespace SmartParking.Infrastructure.Identity;

public class AuthService : IAuthService
{
    private readonly UserManager<AppUser> _userManager;
    private readonly IJwtService _jwtService;

    public AuthService(UserManager<AppUser> userManager, IJwtService jwtService)
    {
        _userManager = userManager;
        _jwtService = jwtService;
    }

    public async Task<AuthResponse> RegisterAsync(RegisterCommand command)
    {
        var user = new AppUser
        {
            UserName = command.Email,
            Email = command.Email,
            FullName = command.FullName
        };

        var result = await _userManager.CreateAsync(user, command.Password);
        if (!result.Succeeded)
        {
            var errors = string.Join(" | ", result.Errors.Select(e => $"{e.Code}: {e.Description}"));
            return new AuthResponse { Success = false, Message = errors };
        }

        await EnsureUserRoleAsync(user);

        return await CreateSessionAsync(user, "Kayıt başarılı.");
    }

    public async Task<AuthResponse> LoginAsync(LoginCommand command)
    {
        var user = await _userManager.FindByEmailAsync(command.Email);
        if (user == null)
            return new AuthResponse { Success = false, Message = "User not found." };

        var valid = await _userManager.CheckPasswordAsync(user, command.Password);
        if (!valid)
            return new AuthResponse { Success = false, Message = "Invalid credentials." };

        await EnsureUserRoleAsync(user);
        return await CreateSessionAsync(user, "Giriş başarılı.");
    }

    public async Task<AuthResponse> RefreshTokenAsync(string refreshToken)
    {
        var user = await _userManager.Users.FirstOrDefaultAsync(u => u.RefreshToken == refreshToken);
        if (user == null || user.RefreshTokenExpiryTime <= DateTime.UtcNow)
            return new AuthResponse { Success = false, Message = "Invalid or expired refresh token." };

        await EnsureUserRoleAsync(user);
        var roles = await _userManager.GetRolesAsync(user);
        var newAccessToken = _jwtService.CreateToken(user.Id, user.Email!, roles);
        var newRefreshToken = _jwtService.CreateRefreshToken();

        user.RefreshToken = newRefreshToken;
        user.RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(7);
        await _userManager.UpdateAsync(user);

        return new AuthResponse
        {
            Success = true,
            Message = "Token refreshed successfully",
            AccessToken = newAccessToken,
            RefreshToken = newRefreshToken,
            ExpiresAt = DateTime.UtcNow.AddHours(1)
        };
    }

    public async Task<AuthResponse> ExternalLoginAsync(
        string provider,
        string providerKey,
        string email,
        string fullName)
    {
        if (string.IsNullOrWhiteSpace(provider)
            || string.IsNullOrWhiteSpace(providerKey)
            || string.IsNullOrWhiteSpace(email))
        {
            return new AuthResponse
            {
                Success = false,
                Message = "Harici kimlik bilgileri eksik."
            };
        }

        var normalizedEmail = email.Trim().ToLowerInvariant();
        var user = await _userManager.FindByLoginAsync(provider, providerKey)
            ?? await _userManager.FindByEmailAsync(normalizedEmail);

        if (user is null)
        {
            user = new AppUser
            {
                UserName = normalizedEmail,
                Email = normalizedEmail,
                FullName = fullName.Trim(),
                EmailConfirmed = true
            };
            var createResult = await _userManager.CreateAsync(user);
            if (!createResult.Succeeded)
            {
                return new AuthResponse
                {
                    Success = false,
                    Message = string.Join(" | ", createResult.Errors.Select(error => error.Description))
                };
            }
        }

        var logins = await _userManager.GetLoginsAsync(user);
        if (!logins.Any(login => login.LoginProvider == provider && login.ProviderKey == providerKey))
        {
            var loginResult = await _userManager.AddLoginAsync(
                user,
                new UserLoginInfo(provider, providerKey, provider));
            if (!loginResult.Succeeded)
            {
                return new AuthResponse
                {
                    Success = false,
                    Message = string.Join(" | ", loginResult.Errors.Select(error => error.Description))
                };
            }
        }

        if (string.IsNullOrWhiteSpace(user.FullName) && !string.IsNullOrWhiteSpace(fullName))
        {
            user.FullName = fullName.Trim();
            await _userManager.UpdateAsync(user);
        }

        await EnsureUserRoleAsync(user);
        return await CreateSessionAsync(user, "Google ile giriş başarılı.");
    }

    private async Task<AuthResponse> CreateSessionAsync(AppUser user, string message)
    {
        var roles = await _userManager.GetRolesAsync(user);
        var accessToken = _jwtService.CreateToken(user.Id, user.Email!, roles);
        var refreshToken = _jwtService.CreateRefreshToken();

        user.RefreshToken = refreshToken;
        user.RefreshTokenExpiryTime = DateTime.UtcNow.AddDays(7);
        var updateResult = await _userManager.UpdateAsync(user);

        if (!updateResult.Succeeded)
        {
            var errors = string.Join(
                " | ",
                updateResult.Errors.Select(error => error.Description));
            return new AuthResponse
            {
                Success = false,
                Message = $"Oturum oluşturulamadı: {errors}"
            };
        }

        return new AuthResponse
        {
            Success = true,
            Message = message,
            AccessToken = accessToken,
            RefreshToken = refreshToken,
            ExpiresAt = DateTime.UtcNow.AddHours(1)
        };
    }

    private async Task EnsureUserRoleAsync(AppUser user)
    {
        if (!await _userManager.IsInRoleAsync(user, "User"))
            await _userManager.AddToRoleAsync(user, "User");
    }
}
