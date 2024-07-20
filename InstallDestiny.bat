::    This file is part of GetUru.
::
::    GetUru is free software: you can redistribute it and/or modify
::    it under the terms of the GNU General Public License as published by
::    the Free Software Foundation, either version 3 of the License, or
::    (at your option) any later version.
::
::    GetUru is distributed in the hope that it will be useful,
::    but WITHOUT ANY WARRANTY; without even the implied warranty of
::    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
::    GNU General Public License for more details.
::
::    You should have received a copy of the GNU General Public License
::    along with GetUru.  If not, see <http://www.gnu.org/licenses/>.

@echo off

:: Prefer to use PowerShell Core, if it's available.
WHERE /Q pwsh.exe
IF %ERRORLEVEL% EQU 0 (
    pwsh.exe -NoProfile -ExecutionPolicy Bypass -File GetUruClient.ps1 -Destiny -Force32Bit
) ELSE (
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File GetUruClient.ps1 -Destiny -Force32Bit
)
PAUSE
