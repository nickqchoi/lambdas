# Secrets Setup Guide

This project uses git-ignored files to manage API keys. If you clone this repository, you will need to manually recreate these files for the app to build.

## 1. Required Files

You must create the following files in your project root:

1.  `.env`
2.  `Configs/Secrets.xcconfig`

## 2. `.env` Template

Create a file named `.env` in the root directory and fill in your keys:

```bash
CLERK_PUBLISHABLE_KEY=pk_test_...
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=sb_secret_...
```

## 3. `Configs/Secrets.xcconfig` Template

Create a directory named `Configs` and a file inside it named `Secrets.xcconfig`.
**Important**: The `SUPABASE_URL` must have the `$()` hack to avoid comment truncation.

```properties
// Secrets.xcconfig
// Imported by Debug/Release config to expose secrets to Info.plist
// DO NOT COMMIT THIS FILE

CLERK_PUBLISHABLE_KEY = pk_test_...
SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_ANON_KEY = sb_secret_...
```

## 4. Xcode Setup (One-time)

After creating the `Configs/Secrets.xcconfig` file, you must add it to Xcode:

1.  Open Project in Xcode.
2.  Drag the `Configs` folder into the Project Navigator (select "Reference files in place", uncheck "Copy").
3.  Go to Project Settings -> Info -> Configurations.
4.  Set the Configuration for the **lambdas-xi-chapter** (App Target) to `Secrets` for both Debug and Release.
