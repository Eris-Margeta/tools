# Vaulter V2

A secure folder backup system that encrypts your data and stores it in Git LFS repositories.

**Think of it as your own private, encrypted backup service - but you control everything.**

## What Does Vaulter Do?

Vaulter takes any folder on your computer, compresses it, encrypts it with military-grade encryption (AES-256), and stores it in a Git repository with LFS support. You can then push this encrypted vault to GitHub, GitLab, or any Git remote - creating a secure offsite backup.

**Only the encrypted file is ever stored remotely. Your password never leaves your computer.**

---

## Quick Start

```bash
# Install dependencies
brew install pigz openssl git git-lfs   # macOS
sudo apt install pigz openssl git git-lfs   # Linux

# Run vaulter
chmod +x vaulter.sh
./vaulter.sh

# Choose [1] VAULT to backup a folder
# Choose [2] DE-VAULT to restore a folder
```

---

## How It Works

### The VAULT Process (Backup)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   FOLDER    │ ──▶ │  COMPRESS   │ ──▶ │   ENCRYPT   │ ──▶ │  GIT LFS    │
│  (your data)│     │  (tar.gz)   │     │ (AES-256)   │     │  (push)     │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                           │                   │
                           ▼                   ▼
                      [DELETED]           [DELETED]
                    after encrypt       after git init
```

**Step by step:**

| Step | What Happens | Files Created | Files Deleted |
|------|--------------|---------------|---------------|
| 1. Compress | Folder → `.tar.gz` | `myfolder.tar.gz` | - |
| 2. Encrypt | `.tar.gz` → `.tar.gz.enc` | `myfolder.tar.gz.enc` | `myfolder.tar.gz` |
| 3. Git Init | Create vault repo | `myfolder-vault/` | - |
| 4. Push | Upload to remote | - | - |

**After vaulting, you have:**
```
myfolder-vault/
├── myfolder.tar.gz.enc    ← Encrypted (safe to store anywhere)
├── .gitattributes         ← LFS configuration
├── .gitignore
├── VAULT_INFO.md          ← Restore instructions
└── .git/
```

**What gets pushed to remote:** Only the encrypted `.enc` file (via Git LFS)

---

### The DE-VAULT Process (Restore)

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│  GIT CLONE  │ ──▶ │   DECRYPT   │ ──▶ │ DECOMPRESS  │ ──▶ │   FOLDER    │
│  (pull LFS) │     │ (password)  │     │  (tar.gz)   │     │ (restored!) │
└─────────────┘     └─────────────┘     └─────────────┘     └─────────────┘
                                               │
                                               ▼
                                          [DELETED]
                                        after extract
```

**Step by step:**

| Step | What Happens | Input | Output |
|------|--------------|-------|--------|
| 1. Clone | Download vault repo | Remote URL | `myfolder-vault/` |
| 2. LFS Pull | Download encrypted file | - | `myfolder.tar.gz.enc` |
| 3. Decrypt | Enter password | `.enc` file | `myfolder.tar.gz` |
| 4. Decompress | Extract archive | `.tar.gz` | `myfolder/` |
| 5. Cleanup | Remove temp files | - | Delete `.tar.gz` |

---

## Detailed Workflows

### Scenario 1: Backup a Local Folder to GitHub

**Goal:** Backup `~/Documents/important-project` to a private GitHub repo

```bash
./vaulter.sh

# Select [1] VAULT
# Enter path: ~/Documents/important-project
# Enter password: [your secure password]
# Confirm password: [repeat]
# Push to remote? y
# Enter URL: git@github.com:username/important-project-vault.git
# Delete original? n (keep for now, delete manually later)
```

**Result:**
- `~/Documents/important-project-vault/` created locally
- Encrypted backup pushed to GitHub
- Original folder untouched (you chose not to delete)

**What exists where:**

| Location | Files | Encrypted? |
|----------|-------|------------|
| Your computer | Original folder + vault folder | Original: No, Vault: Yes |
| GitHub | Only `.enc` file | Yes |

---

### Scenario 2: Restore from GitHub to a New Computer

**Goal:** Recover `important-project` on a fresh machine

```bash
./vaulter.sh

# Select [2] DE-VAULT
# Restore from: [2] Remote repository
# Enter URL: git@github.com:username/important-project-vault.git
# Clone to: ~/restored-vault
# Enter password: [your password from backup]
# Delete vault after restore? y
```

**Result:**
- `~/important-project/` restored with all your files
- Vault directory deleted (you chose yes)

---

### Scenario 3: Manual Restore (Without Vaulter)

If you don't have vaulter available, you can restore manually:

```bash
# 1. Clone the repository
git clone git@github.com:username/important-project-vault.git
cd important-project-vault

# 2. Pull the LFS file
git lfs pull

# 3. Decrypt (you'll be prompted for password)
openssl enc -d -aes-256-cbc -salt -pbkdf2 -iter 600000 \
    -in important-project.tar.gz.enc \
    -out important-project.tar.gz

# 4. Extract
tar -xzf important-project.tar.gz

# 5. Cleanup
rm important-project.tar.gz
```

---

## Security Details

### Encryption Specification

| Property | Value |
|----------|-------|
| Algorithm | AES-256-CBC |
| Key Derivation | PBKDF2 |
| Iterations | 600,000 |
| Salt | Random (stored in encrypted file) |

**What this means:**
- AES-256 is used by governments and military worldwide
- PBKDF2 with 600k iterations makes brute-force attacks infeasible
- Even with a supercomputer, cracking a strong password would take longer than the age of the universe

### What's Stored Where?

| Data | Your Computer | Remote (GitHub/GitLab) |
|------|---------------|------------------------|
| Original folder | Yes (until you delete) | **Never** |
| Unencrypted archive | **Never** (deleted immediately) | **Never** |
| Encrypted `.enc` file | Yes (in vault folder) | Yes (via Git LFS) |
| Password | **Never stored** | **Never** |

### Security Best Practices

1. **Use a strong password** - At least 16 characters, mix of letters/numbers/symbols
2. **Store your password safely** - Use a password manager
3. **Delete originals after verifying** - Test restore before deleting source
4. **Use private repositories** - Don't expose your vault URLs publicly
5. **Don't reuse passwords** - Each vault should have a unique password

---

## File Locations Summary

### After VAULT

```
/path/to/
├── myfolder/              ← Original (kept unless you delete)
└── myfolder-vault/        ← NEW: The vault
    ├── myfolder.tar.gz.enc    ← Encrypted backup
    ├── .gitattributes
    ├── .gitignore
    ├── VAULT_INFO.md
    └── .git/
```

### After DE-VAULT

```
/path/to/
├── myfolder-vault/        ← Vault (kept unless you delete)
│   └── myfolder.tar.gz.enc
└── myfolder/              ← NEW: Restored folder
    └── (all your files)
```

---

## Menu Reference

| Option | Name | Description |
|--------|------|-------------|
| **1** | VAULT | Full backup workflow (compress → encrypt → git → push) |
| **2** | DE-VAULT | Full restore workflow (pull → decrypt → decompress) |
| 3 | Compress | Only create `.tar.gz` archive |
| 4 | Encrypt | Only encrypt a file with AES-256 |
| 5 | Decrypt | Only decrypt a `.enc` file |
| 6 | Decompress | Only extract a `.tar.gz` archive |
| 7 | Push | Push existing vault to remote |
| 8 | Pull | Clone vault from remote |
| 0 | Set Path | Set default working directory |
| h | Help | Show help information |
| q | Quit | Exit vaulter |

---

## Requirements

| Tool | Purpose | Install (macOS) | Install (Linux) |
|------|---------|-----------------|-----------------|
| pigz | Fast parallel compression | `brew install pigz` | `apt install pigz` |
| openssl | Encryption/decryption | `brew install openssl` | `apt install openssl` |
| git | Version control | `brew install git` | `apt install git` |
| git-lfs | Large file storage | `brew install git-lfs` | `apt install git-lfs` |

**One-liner install:**

```bash
# macOS
brew install pigz openssl git git-lfs

# Debian/Ubuntu
sudo apt install pigz openssl git git-lfs
```

---

## FAQ

### Q: What if I forget my password?

**Your data is unrecoverable.** The encryption is designed to be unbreakable without the password. Use a password manager.

### Q: Can I change the password later?

No. You would need to de-vault with the old password and re-vault with a new one.

### Q: Is this safe to use with public repositories?

Yes, but not recommended. The encrypted file is safe, but there's no reason to expose it publicly. Use private repos.

### Q: How large can my folders be?

Limited only by your storage and Git LFS quota:
- GitHub: 2GB per file, varies by plan for total storage
- GitLab: 5GB per file

### Q: Does this work on Windows?

Not natively. Use WSL (Windows Subsystem for Linux) to run it.

### Q: Why Git LFS instead of regular Git?

Regular Git stores file history, which bloats the repo. Git LFS stores large files externally, keeping the repo small and fast.

---

## Troubleshooting

### "Decryption failed"

- Wrong password
- File corrupted during transfer
- File encrypted with different PBKDF2 iterations (older version)

### "LFS files not downloaded"

Run `git lfs pull` in the vault directory.

### "Push failed"

- Check your Git remote URL
- Ensure you have write access to the repository
- Verify Git LFS is enabled on the remote (GitHub/GitLab settings)

---

## For Developers

### Project Structure

```
vaulter/
├── vaulter.sh              # Main application (877 lines)
├── vaulter_validation.sh   # Test runner entry point
├── README.md               # This file
└── testing_tools/          # Test suite
    ├── test_utils.sh       # Shared test framework & utilities
    ├── unit_tests.sh       # Unit tests (29 tests)
    ├── integration_tests.sh # Integration tests (23 tests)
    └── security_tests.sh   # Security tests (19 tests)
```

### Running Tests

**Before submitting any changes, ALL tests must pass.**

```bash
# Run all tests (required before any PR)
./vaulter_validation.sh

# Quick smoke test (useful during development)
./vaulter_validation.sh quick

# Run specific test suites
./vaulter_validation.sh unit         # Unit tests only
./vaulter_validation.sh integration  # Integration tests only
./vaulter_validation.sh security     # Security tests only

# List all available tests
./vaulter_validation.sh list

# Check prerequisites
./vaulter_validation.sh prereq
```

### Test Coverage

| Suite | Tests | Purpose |
|-------|-------|---------|
| **Unit** | 29 | Individual functions: compress, encrypt, decrypt, decompress |
| **Integration** | 23 | Full vault/de-vault workflows, roundtrip integrity |
| **Security** | 19 | Encryption strength, data handling, no plaintext leakage |

**Total: 71+ tests**

### Development Workflow

1. **Before making changes:**
   ```bash
   ./vaulter_validation.sh quick   # Verify baseline works
   ```

2. **Make your changes to `vaulter.sh`**

3. **Run the full test suite:**
   ```bash
   ./vaulter_validation.sh         # ALL tests must pass
   ```

4. **If adding new features:**
   - Add corresponding tests in `testing_tools/`
   - Unit tests for new functions
   - Integration tests for new workflows
   - Security tests if touching encryption/data handling

### Writing Tests

Tests use a simple framework defined in `test_utils.sh`:

```bash
# Example test function
test_my_new_feature() {
    # Setup
    local folder=$(create_test_folder "test_data")

    # Action
    my_function "$folder"

    # Assert
    assert_file_exists "$folder/output.txt" "Output should be created"
    assert_file_contains "$folder/output.txt" "expected" "Should contain expected content"
}

# Register the test
run_test "My new feature works" test_my_new_feature
```

**Available assertions:**
- `assert_true` / `assert_false`
- `assert_equals` / `assert_not_equals`
- `assert_file_exists` / `assert_file_not_exists`
- `assert_dir_exists` / `assert_dir_not_exists`
- `assert_file_contains` / `assert_file_not_contains`
- `assert_command_succeeds` / `assert_command_fails`
- `assert_files_equal`
- `assert_file_size_greater_than`

**Test helpers:**
- `create_test_folder "name"` - Creates folder with sample files
- `create_test_folder_with_size "name" 1024` - Creates folder with specific KB size
- `get_folder_checksum "$folder"` - SHA256 checksum for integrity verification
- `vaulter_encrypt`, `vaulter_decrypt`, `vaulter_compress` - Direct operations

### Code Standards

1. **Security is paramount**
   - Never store passwords in files or logs
   - Always delete unencrypted intermediate files
   - Use secure deletion when available (`shred`)
   - Validate all user inputs

2. **Encryption requirements**
   - AES-256-CBC with PBKDF2
   - Minimum 600,000 iterations
   - Random salt for each encryption
   - Password prompted interactively (never on command line)

3. **Git LFS requirements**
   - Only `.enc` files tracked by LFS
   - `.gitattributes` must NOT be tracked by LFS
   - `.gitignore` must exclude unencrypted archives

4. **Error handling**
   - All operations should fail gracefully
   - Clean up temp files on failure
   - Provide clear error messages

5. **User experience**
   - Confirm before destructive operations
   - Show progress during long operations
   - Provide clear summaries

### Configuration Constants

These are defined at the top of `vaulter.sh`:

```bash
PBKDF2_ITERATIONS=600000   # Key derivation iterations
CIPHER="aes-256-cbc"       # Encryption algorithm
VERSION="2.0.0"            # Version string
```

**Do not reduce `PBKDF2_ITERATIONS`** - this is a security-critical value.

### Common Issues During Development

**Tests fail with "command not found":**
```bash
./vaulter_validation.sh prereq   # Check all tools installed
```

**Tests pass locally but fail in CI:**
- Ensure no hardcoded paths
- Check for macOS vs Linux `stat` differences
- Verify temp directory cleanup

**Encryption tests are slow:**
- This is expected due to 600k PBKDF2 iterations
- Use `./vaulter_validation.sh quick` during iteration

### Submitting Changes

1. Fork the repository
2. Create a feature branch
3. Make changes
4. Run `./vaulter_validation.sh` - **ALL tests must pass**
5. Update README if adding user-facing features
6. Submit pull request with clear description

---

## Version History

| Version | Changes |
|---------|---------|
| 2.0.0 | Complete rewrite: PBKDF2 encryption, proper Git LFS handling, secure cleanup, comprehensive test suite |
| 1.0.0 | Initial release |

---

## License

MIT License - Use freely, but remember: **you are responsible for your passwords and backups.**
