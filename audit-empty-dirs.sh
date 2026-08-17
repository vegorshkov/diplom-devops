#!/bin/bash

PROJECT_DIR="/home/vgorshkov/STUDENT1/PROJECT/diplom-devops"

echo "============================================================"
echo "АУДИТ ПУСТЫХ ДИРЕКТОРИЙ ПРОЕКТА"
echo "Дата: $(date '+%Y-%m-%d %H:%M:%S')"
echo "============================================================"
echo

cd "$PROJECT_DIR" || exit 1

echo "Пустые директории:"
echo "------------------------------------------------------------"

find . -type d -empty -not -path "./.git/*" -not -path "./.terraform/*" | sort

echo
echo "------------------------------------------------------------"
echo "Всего пустых директорий: $(find . -type d -empty -not -path "./.git/*" -not -path "./.terraform/*" | wc -l)"
echo
echo "============================================================"
