using System.Reflection;

namespace Jotter.Application;

// Mốc để Api quét Command, Query và Validator của assembly này khi đăng ký DI.
public static class AssemblyReference
{
    public static readonly Assembly Assembly = typeof(AssemblyReference).Assembly;
}
