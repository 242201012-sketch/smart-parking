# 1. Build aşaması
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Proje dosyalarını kopyala
COPY SmartParking.API/SmartParking.API.csproj SmartParking.API/
COPY SmartParking.Application/SmartParking.Application.csproj SmartParking.Application/
COPY SmartParking.Domain/SmartParking.Domain.csproj SmartParking.Domain/
COPY SmartParking.Infrastructure/SmartParking.Infrastructure.csproj SmartParking.Infrastructure/

# Restore bağımlılıkları
RUN dotnet restore SmartParking.API/SmartParking.API.csproj

# Tüm solution'u kopyala ve publish et
COPY . .
WORKDIR /src/SmartParking.API
RUN dotnet publish -c Release -o /app/publish

# 2. Runtime aşaması
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
ENV ASPNETCORE_URLS=http://+:8080
EXPOSE 8080
USER $APP_UID
ENTRYPOINT ["dotnet", "SmartParking.API.dll"]
