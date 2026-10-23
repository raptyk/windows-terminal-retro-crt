<#
.SYNOPSIS
    Compiles every shader in ..\shaders with the system D3D compiler (d3dcompiler_47.dll),
    the same way Windows Terminal does, and reports errors. Exit code 1 when any shader fails.
#>
$ErrorActionPreference = 'Stop'

if (-not ('RetroCrt.ShaderCompiler' -as [type])) {
    Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

namespace RetroCrt {
    public static class ShaderCompiler {
        [DllImport("d3dcompiler_47.dll", CharSet = CharSet.Ansi)]
        private static extern int D3DCompile(byte[] source, IntPtr sourceSize, string sourceName, IntPtr defines, IntPtr include,
            string entryPoint, string target, uint flags1, uint flags2, out IntPtr code, out IntPtr errors);

        [ComImport, Guid("8BA5FB08-5195-40e2-AC58-0D989C3A0102"), InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
        private interface ID3DBlob {
            [PreserveSig] IntPtr GetBufferPointer();
            [PreserveSig] IntPtr GetBufferSize();
        }

        // Returns null on success, otherwise the compiler messages.
        public static string Compile(string path) {
            byte[] source = System.IO.File.ReadAllBytes(path);
            IntPtr code, errors;
            int hr = D3DCompile(source, (IntPtr)source.Length, path, IntPtr.Zero, IntPtr.Zero, "main", "ps_4_0", 0, 0, out code, out errors);
            string messages = "";
            if (errors != IntPtr.Zero) {
                var blob = (ID3DBlob)Marshal.GetObjectForIUnknown(errors);
                messages = Marshal.PtrToStringAnsi(blob.GetBufferPointer(), (int)blob.GetBufferSize());
            }
            return hr == 0 ? null : string.Format("HRESULT 0x{0:X8}: {1}", hr, messages);
        }
    }
}
'@
}

$failed = 0
Get-ChildItem (Join-Path $PSScriptRoot '..\shaders') -Filter '*.hlsl' | ForEach-Object {
    $result = [RetroCrt.ShaderCompiler]::Compile($_.FullName)
    if ($result) {
        Write-Host "FAIL $($_.Name)  $result" -ForegroundColor Red
        $failed++
    } else {
        Write-Host "OK   $($_.Name)" -ForegroundColor Green
    }
}
if ($failed) { exit 1 }
