# 🚀 PostgreSQL Migration Tool PRO

![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)
![Platform: Windows](https://img.shields.io/badge/Platform-Windows-blue.svg)
![PowerShell](https://img.shields.io/badge/PowerShell-5.1+-blue.svg)
![PostgreSQL](https://img.shields.io/badge/PostgreSQL-13%20to%2018-336791.svg)

A professional, feature-rich graphical migration tool built in PowerShell with Windows Presentation Foundation (WPF). Whether you are moving databases between servers, creating backups, importing existing dumps, or even migrating from MySQL to PostgreSQL, this tool provides a seamless, unblocked UI experience.

## ✨ Features

- **🛡️ Secure Password Storage**: Encrypts and stores your database passwords locally using Windows DPAPI.
- **🔄 Multiple Migration Modes**:
  - **Direct Migration**: Stream data directly from Source to Target without intermediate files.
  - **Export Only**: Dump databases to a file or directory.
  - **Import Only**: Restore databases from an existing dump.
  - **MySQL to PostgreSQL**: Utilize `pgloader` to migrate from MySQL.
- **🚀 Asynchronous Execution**: Built on Runspaces to ensure the GUI remains fully responsive during long-running tasks.
- **🛠️ Automated Tool Management**: Automatically downloads and extracts EnterpriseDB PostgreSQL binaries, `pgloader`, and MySQL clients when needed.
- **✅ Robust Data Verification**: Features "Quick" and "Precise" verification modes to validate restored migrations.
- **🌍 Internationalization (i18n)**: Automatically detects your system language (Supports English and German).
- **💾 Templates**: Save configurations for your source and target servers for quick access.
- **👥 Role Migration**: Migrate users and roles (Requires Superuser privileges).
- **⚡ Concurrency**: Define the number of parallel jobs to speed up the migration process.

## 📋 Prerequisites

- **OS**: Windows OS
- **Framework**: PowerShell 5.1 or later (.NET Framework for WPF)
- Internet connection (for initial automated binary downloads)

## 🚀 Getting Started

1. **Clone or Download** this repository.
2. Ensure you have the `MainWindow.xaml` and `pg_migrate_pro.ps1` in the same directory.
3. Open a PowerShell console.
4. Execute the script:
   ```powershell
   .\pg_migrate_pro.ps1
   ```

## 🖥️ Usage

1. **Version Selection**: Choose your desired PostgreSQL client version from the dropdown. Click **Download Tools** if it's your first time or if the binaries are missing.
2. **Migration Mode**: Select Direct, Export, Import, or MySQL -> PostgreSQL.
3. **Source/Target Configurations**: Fill in your database connection details. You can save these configurations as templates for future use.
4. **Test Connections**: Use the "Test & Fetch DBs" and "Test Target Connection" buttons to ensure your credentials and network are working.
5. **Select Databases**: Check the databases you wish to migrate.
6. **Start Migration**: Click **START MIGRATION** and monitor the progress and logs in the application.

## 📁 Project Structure

```text
├── pg_migrate_pro.ps1   # Main PowerShell Script with WPF integration
├── MainWindow.xaml      # XAML layout for the User Interface
├── config.json          # Auto-generated configuration persistence file
├── logs/                # Log directory for migration outputs
├── dumps/               # Default directory for database dumps
└── tools/               # Auto-downloaded third-party tools (pgloader, mysql)
```

## ⚖️ Disclaimer

This script is provided "as is", without warranty of any kind, express or implied, including but not limited to the warranties of merchantability, fitness for a particular purpose, and non-infringement. In no event shall the authors or copyright holders be liable for any claim, damages, or other liability, whether in an action of contract, tort, or otherwise, arising from, out of, or in connection with the software or the use or other dealings in the software. Always make sure to test migrations in a safe environment before applying them to production!

## 📜 License

MIT License

Copyright (c) 2026 Adromir

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

---
**Creator:** [Adromir](https://github.com/adromir)
