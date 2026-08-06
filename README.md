<p align="center"><h1 align="center">CAPSTONE</h1></p>
<p align="center">
	<em>LINUX SYSTEM PROJECT</em>
</p>
<br>

## 🔗 Table of Contents

- [📍 Overview](#-overview)
- [👥 Team members](#-team-members)
- [📁 Project Structure](#-project-structure)
- [👾 Features](#-features)
- [📜 License](#-license)
---

# 📍 Overview

This is a winUI3 app provides sales management features for a small food store.  
The system is designed for a single owner who also acts as the salesperson, inventory manager, and delivery staff.

---

# 👥 Team members

| Fullname | Student ID | Role |
|---|---|---|
| Pham Thanh Dat | 23127179 | Team Leader |

---

# 📁 Project Structure

```
DominiShop/                          ← Solution root
├── DominiShop.slnx                  ← Solution file
└── client/                          ← Main project folder
    ├── DominiShop.csproj            ← Project file (NuGet refs, build config)
    ├── App.xaml                     ← Application resources & theme
    ├── App.xaml.cs                  ← App entry point + DI service registration
    ├── app.manifest                 ← Windows app manifest
    ├── appsettings.json             ← Connection strings & Supabase config
    │
    ├── Assets/                      ← App icons and splash screen images
    │
    ├── Model/                       ← EF Core entity models
    │   ├── BaseModel.cs             ← INotifyPropertyChanged + ICloneable base
    │
    ├── DataAccess/                  ← EF Core DbContext
    │   ├── PostgresContext.cs       ← DbSets + Fluent API model configuration
    │   └── PostgresContext.Extension.cs  ← OnConfiguring (reads appsettings.json)
    │
    ├── Repository/                  ← Data access layer (raw DB queries)
    │
    ├── Service/                     ← Business logic layer
    │
    ├── ViewModel/                   ← Presentation logic (MVVM)
    │
    ├── View/                        ← XAML pages & windows
    │
    ├── Converter/                   ← IValueConverter implementations (XAML binding)
    │
    └── Core/                        ← (Reserved — empty folder for future shared utilities)
```

---

# 👾 Features



---

# 📜 License

This project is developed for educational purposes only.

Copyright © 2026  
All rights reserved by the project team.

This software may not be copied, modified, or distributed for commercial purposes without permission from the authors.

---