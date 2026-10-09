# Railway: Root Directory = backend/
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

COPY Directory.Build.props Directory.Packages.props ./
COPY src/Jotter.Domain/Jotter.Domain.csproj src/Jotter.Domain/
COPY src/Jotter.Application/Jotter.Application.csproj src/Jotter.Application/
COPY src/Jotter.Infrastructure/Jotter.Infrastructure.csproj src/Jotter.Infrastructure/
COPY src/Jotter.Api/Jotter.Api.csproj src/Jotter.Api/
RUN dotnet restore src/Jotter.Api/Jotter.Api.csproj

COPY src/ src/
RUN dotnet publish src/Jotter.Api/Jotter.Api.csproj -c Release -o /app/publish --no-restore

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
ENV ASPNETCORE_HTTP_PORTS=8080
EXPOSE 8080
COPY --from=build /app/publish .
ENTRYPOINT ["dotnet", "Jotter.Api.dll"]
