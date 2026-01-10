#!/bin/bash

# Variable to store the absolute folder path
absolute_folder_path=""

# Check prerequisites
echo "Ensure the following tools are installed: pigz, openssl, git, git-lfs"
echo "Install using: brew install pigz openssl git git-lfs (macOS) or sudo apt install pigz openssl git git-lfs (Linux)"
echo

# Menu
while true; do
  echo "Choose an option:"
  echo "0) Absolute-folder-path"
  echo "1) Compress"
  echo "2) Encrypt"
  echo "3) Git LFS Init"
  echo "4) Push to Remote Origin"
  echo "5) Decrypt"
  echo "6) Decompress"
  echo "7) Documentation"
  echo "8) Exit"
  read -r -p "Enter your choice: " choice

  case $choice in
  0)
    if [ -n "$absolute_folder_path" ]; then
      echo "Current absolute folder path: $absolute_folder_path"
    else
      read -r -p "Enter the absolute folder path: " absolute_folder_path
    fi
    ;;

  1)
    folder=${absolute_folder_path:-""}
    if [ -z "$folder" ]; then
      read -r -p "Enter the absolute path of the folder to compress: " folder
    fi
    if [ -d "$folder" ]; then
      tar --use-compress-program=pigz -czvf "$folder/$(basename "$folder").tar.gz" -C "$(dirname "$folder")" "$(basename "$folder")"
      echo "Compressed file created: $folder/$(basename "$folder").tar.gz"
    else
      echo "Invalid folder path."
    fi
    ;;

  2)
    folder=${absolute_folder_path:-""}
    if [ -z "$folder" ]; then
      read -r -p "Enter the absolute path of the file to encrypt: " file
    else
      read -r -p "Enter the name of the file to encrypt (relative to $folder): " file_name
      file="$folder/$file_name"
    fi
    if [ -f "$file" ]; then
      read -r -sp "Enter password: " password
      echo
      read -r -sp "Confirm password: " confirm
      echo
      if [ "$password" = "$confirm" ]; then
        openssl enc -aes-256-cbc -salt -in "$file" -out "$file.enc" -pass pass:"$password"
        echo "Encrypted file created: $file.enc"
      else
        echo "Passwords do not match."
      fi
    else
      echo "Invalid file path."
    fi
    ;;

  3)
    folder=${absolute_folder_path:-""}
    if [ -z "$folder" ]; then
      read -r -p "Enter the absolute path of the folder to initialize as a Git repository: " folder
    fi
    if [ -d "$folder" ]; then
      cd "$folder" || exit
      git init
      echo ".DS_Store" >.gitignore
      git lfs install
      git lfs track "*"
      git add .
      git commit -m "Initial commit - by script"
      git branch -M main
      echo "Git repository initialized with Git LFS and .DS_Store ignored."
    else
      echo "Invalid folder path."
    fi
    ;;

  4)
    folder=${absolute_folder_path:-""}
    if [ -z "$folder" ]; then
      read -r -p "Enter the absolute path of the folder containing the Git repository: " folder
    fi
    if [ -d "$folder/.git" ]; then
      cd "$folder" || exit
      read -r -p "Enter the new remote origin URL: " url
      git remote add origin "$url"
      git push -uf origin main
      echo "Pushed to remote origin: $url"
    else
      echo "No Git repository found in the specified folder."
    fi
    ;;

  5)
    folder=${absolute_folder_path:-""}
    if [ -z "$folder" ]; then
      read -r -p "Enter the absolute path of the folder containing the .enc file(s): " folder
    fi
    if [ -d "$folder" ]; then
      enc_files=("$folder"/*.enc)
      if [ "${#enc_files[@]}" -eq 1 ]; then
        file="${enc_files[0]}"
      elif [ "${#enc_files[@]}" -gt 1 ]; then
        echo "Multiple .enc files found in the folder:"
        for f in "${enc_files[@]}"; do
          echo "- $(basename "$f")"
        done
        read -r -p "Enter the name of the .enc file to decrypt: " file_name
        file="$folder/$file_name"
      else
        echo "No .enc files found in the specified folder."
        continue
      fi

      if [ -f "$file" ]; then
        read -r -sp "Enter the decryption password: " password
        echo
        openssl enc -d -aes-256-cbc -in "$file" -out "${file%.enc}" -pass pass:"$password"
        echo "Decrypted file created: ${file%.enc}"
      else
        echo "Specified .enc file does not exist."
      fi
    else
      echo "Invalid folder path."
    fi
    ;;

  6)
    folder=${absolute_folder_path:-""}
    if [ -z "$folder" ]; then
      read -r -p "Enter the absolute path of the folder containing the tar.gz file(s): " folder
    fi
    if [ -d "$folder" ]; then
      tar_files=("$folder"/*.tar.gz)
      if [ "${#tar_files[@]}" -eq 1 ]; then
        file="${tar_files[0]}"
      elif [ "${#tar_files[@]}" -gt 1 ]; then
        echo "Multiple tar.gz files found in the folder:"
        for f in "${tar_files[@]}"; do
          echo "- $(basename "$f")"
        done
        read -r -p "Enter the name of the tar.gz file to decompress: " file_name
        file="$folder/$file_name"
      else
        echo "No tar.gz files found in the specified folder."
        continue
      fi

      if [ -f "$file" ]; then
        tar -xzvf "$file" -C "$folder"
        echo "Decompressed file: $file"
      else
        echo "Specified tar.gz file does not exist."
      fi
    else
      echo "Invalid folder path."
    fi
    ;;

  7)
    echo "Documentation:"
    echo "1. Ensure the following tools are installed: pigz, openssl, git, git-lfs."
    echo "2. Install them using:"
    echo "   - macOS: brew install pigz openssl git git-lfs"
    echo "   - Linux: sudo apt install pigz openssl git git-lfs"
    echo "3. For GitHub repositories, ensure you are logged in using 'gh auth login'."
    echo "4. Git LFS requires sufficient storage space for large files."
    ;;

  8)
    echo "Exiting..."
    break
    ;;

  *)
    echo "Invalid choice. Please try again."
    ;;
  esac
  echo
done
