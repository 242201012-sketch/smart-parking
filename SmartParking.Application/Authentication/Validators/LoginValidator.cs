using FluentValidation;
using SmartParking.Application.Authentication.Commands.Login;

namespace SmartParking.Application.Authentication.Validators;

public class LoginValidator : AbstractValidator<LoginCommand>
{
    public LoginValidator()
    {
        RuleFor(x => x.Email)
            .NotEmpty()
            .EmailAddress();

        RuleFor(x => x.Password)
            .NotEmpty();
    }
}