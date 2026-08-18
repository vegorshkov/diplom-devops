#!/bin/bash

# Переменные
output_file="../../infra-app.txt"
current_dir="./"

# Очищаем или создаем выходной файл
> "$output_file"

# Функция для проверки, является ли файл графическим
is_image_file() {
    local file="$1"
    local mime_type=$(file -b --mime-type "$file" 2>/dev/null)
    
    # Проверяем MIME-типы изображений
    if [[ "$mime_type" == image/* ]]; then
        return 0
    fi
    
    # Дополнительная проверка по расширениям графических файлов
    local ext="${file##*.}"
    ext="${ext,,}" # приводим к нижнему регистру
    case "$ext" in
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|svg|ico|heic|heif|raw|psd|ai|eps)
            return 0
            ;;
    esac
    
    return 1
}

# Функция для проверки, нужно ли исключить файл
should_exclude_file() {
    local base_name="$1"
    
    # Исключаем файлы сканирования
    case "$base_name" in
        "scan.sh"|"scan1.sh"|"scan2.sh"|"terraform.tfvars"|"authorized_key.json"|"$output_file")
            return 0
            ;;
    esac
    
    return 1
}

# Функция для рекурсивного обхода каталогов
traverse_dir() {
    local dir="$1"
    local indent="$2"
    
    # Перебираем все элементы в каталоге (включая скрытые)
    for item in "$dir"/* "$dir"/.[!.]* "$dir"/..?*; do
        # Пропускаем несуществующие (когда шаблоны не нашли файлы)
        [ -e "$item" ] || continue
        
        # Получаем базовое имя элемента
        local base_name=$(basename "$item")
        
        # Пропускаем . и ..
        if [ "$base_name" = "." ] || [ "$base_name" = ".." ]; then
            continue
        fi
        
        # Пропускаем папку .git
        if [ -d "$item" ] && [ "$base_name" = ".git" ]; then
            continue
        fi
        
        # Пропускаем исключаемые файлы
        if [ -f "$item" ] && should_exclude_file "$base_name"; then
            continue
        fi
        
        # Записываем информацию об элементе
        if [ -d "$item" ]; then
            # Это каталог
            echo "${indent}[DIR] $item" >> "$output_file"
            # Рекурсивно обходим подкаталог
            traverse_dir "$item" "$indent    "
        elif [ -f "$item" ]; then
            # Проверяем расширение файла
            local ext="${item##*.}"
            ext="${ext,,}" # приводим к нижнему регистру
            
            # Пропускаем файлы с расширением .md
            if [ "$ext" = "md" ]; then
                continue
            fi
            
            # Проверяем, является ли файл графическим
            if is_image_file "$item"; then
                echo "${indent}[IMAGE] $item (графический файл - пропущен)" >> "$output_file"
                continue
            fi
            
            # Это файл
            echo "${indent}[FILE] $item" >> "$output_file"
            
            # Пытаемся прочитать файл, если это текстовый файл
            if [ -r "$item" ] && [[ "$(file -b --mime-type "$item")" == text/* ]]; then
                echo "${indent}Содержимое файла $item:" >> "$output_file"
                echo "${indent}========================================" >> "$output_file"
                # Добавляем отступ к каждой строке содержимого
                cat "$item" 2>/dev/null | sed "s/^/${indent}/" >> "$output_file" 2>/dev/null
                echo "${indent}========================================" >> "$output_file"
            else
                echo "${indent}Нечитаемый файл или бинарный файл" >> "$output_file"
            fi
        elif [ -L "$item" ]; then
            # Это символическая ссылка
            echo "${indent}[LINK] $item -> $(readlink "$item")" >> "$output_file"
        else
            # Другие типы файлов
            echo "${indent}[OTHER] $item" >> "$output_file"
        fi
    done
}

# Функция для генерации tree с исключениями
generate_tree() {
    echo "Структура проекта (tree):" >> "$output_file"
    echo "========================================" >> "$output_file"
    
    # Создаем временный файл с паттернами для исключения
    local exclude_patterns=""
    
    # Базовые исключения
    exclude_patterns="-I '.git"
    
    # Исключаем графические файлы по расширениям
    exclude_patterns="$exclude_patterns|*.jpg|*.jpeg|*.png|*.gif|*.bmp|*.tiff|*.tif|*.webp|*.svg|*.ico|*.heic|*.heif|*.raw|*.psd|*.ai|*.eps"
    
    # Исключаем md файлы
    exclude_patterns="$exclude_patterns|*.md"
    
    # Исключаем файлы сканирования
    exclude_patterns="$exclude_patterns|scan.sh|scan1.sh|scan2.sh"
    
    # Закрываем паттерн
    exclude_patterns="$exclude_patterns'"
    
    # Выполняем tree с исключениями
    if command -v tree &> /dev/null; then
        tree $exclude_patterns --charset=utf-8 >> "$output_file" 2>/dev/null || echo "tree не смог обработать директорию" >> "$output_file"
    else
        echo "Команда tree не установлена. Установите: sudo apt-get install tree" >> "$output_file"
        # Запасной вариант - используем find для создания простого дерева
        echo "Альтернативное дерево (find):" >> "$output_file"
        find . -not -path './.git/*' -not -path './.git' \
             -not -name '*.jpg' -not -name '*.jpeg' -not -name '*.png' -not -name '*.gif' \
             -not -name '*.bmp' -not -name '*.tiff' -not -name '*.tif' -not -name '*.webp' \
             -not -name '*.svg' -not -name '*.ico' -not -name '*.heic' -not -name '*.heif' \
             -not -name '*.raw' -not -name '*.psd' -not -name '*.ai' -not -name '*.eps' \
             -not -name '*.md' \
             -not -name 'scan.sh' -not -name 'scan1.sh' -not -name 'scan2.sh' \
             | sort | sed -e 's/[^/]*\//|   /g' -e 's/|   \([^|]\)/|-- \1/' >> "$output_file"
    fi
    
    echo "" >> "$output_file"
    echo "========================================" >> "$output_file"
    echo "" >> "$output_file"
}

# Запускаем обход с текущего каталога
echo "Начало сканирования каталога: $current_dir" >> "$output_file"
echo "Время: $(date)" >> "$output_file"
echo "Исключены: .git/, *.md, графические файлы, scan.sh, scan1.sh, scan2.sh" >> "$output_file"
echo "========================================" >> "$output_file"
echo "" >> "$output_file"

# Добавляем tree в начало файла
generate_tree

# Затем запускаем детальное сканирование
echo "ДЕТАЛЬНОЕ СОДЕРЖИМОЕ ФАЙЛОВ:" >> "$output_file"
echo "========================================" >> "$output_file"
echo "" >> "$output_file"

traverse_dir "$current_dir" ""

echo "" >> "$output_file"
echo "Сканирование завершено." >> "$output_file"
echo "Результат сохранен в: $output_file" >> "$output_file"

