#!/usr/bin/env bash
#
# safe-shell-functions.sh - cd (geçmişli) ve mkdir (dizine gir sorulu) fonksiyonları
#
# *** ÖNEMLİ - BU DOSYA ÇALIŞTIRILMAZ, "SOURCE" EDİLİR ***
#
# rm/ls'in aksine, cd bir bash BUILTIN'idir ve mkdir'in "oluşturduğu dizine
# gir" özelliği de mevcut shell'in bulunduğu dizini değiştirmek zorundadır.
# Bir alt process (yani ayrı bir script dosyası) asla kendi ebeveyn shell'inin
# çalışma dizinini değiştiremez - bu Unix'in temel bir kuralıdır, bizim
# script'imizin bir eksikliği değil. Bu yüzden cd ve mkdir, PATH'e konan birer
# dosya olarak DEĞİL, doğrudan sizin interaktif shell'inizin içine TANIMLANMIŞ
# birer BASH FONKSİYONU olarak çalışmak zorunda.
#
# KURULUM
#   1) Bu dosyayı kalıcı bir yere koy, örn:
#        mkdir -p ~/.local/share/safe-shell-tools
#        cp safe-shell-functions.sh ~/.local/share/safe-shell-tools/
#
#   2) ~/.bashrc dosyanın SONUNA şu satırı ekle:
#        source ~/.local/share/safe-shell-tools/safe-shell-functions.sh
#
#   3) Yeni bir terminal aç ya da: source ~/.bashrc
#
#   4) Doğrula: `type cd` yazdığında "cd is a function" çıktısını görmelisin
#      (bir dosya yolu değil).
#
# KULLANIM
#   cd bir/yol                 -> normal cd, TÜM gerçek cd davranışı korunur
#                                  (cd, cd -, cd ~, cd -L/-P, hepsi aynen çalışır)
#   cd -h   veya   cd --history -> şimdiye kadar gidilen dizinleri numaralı listeler
#   cd 3!                       -> geçmişteki 3 numaralı dizine gider
#
#   mkdir yeniklasor             -> dizini oluşturur, TEK bir dizin verildiyse
#                                   "Dizin içine girilsin mi? (y/n)" diye sorar
#   mkdir -p a/b/c                -> aynı şekilde çalışır, a/b/c oluşur, girmek
#                                   istersen c'nin içine girer
#   mkdir a b c                   -> birden fazla dizin verildiyse SORMAZ
#                                   (hangisine girileceği belirsiz olduğu için)
#
# BİLİNEN SINIRLAR
#   - cd geçmişi ~/.local/share/safecd_history dosyasında büyür, elle
#     silebilirsin: `rm -f ~/.local/share/safecd_history` (gerçek rm ile, ya
#     da saferm kuruluysa onunla).
#   - mkdir'in "içine gir mi" sorusu yalnızca girdi bir terminalden (TTY)
#     geliyorsa sorulur; bir script içinden çağrılırsa sessizce sorulmaz,
#     sadece dizini oluşturur (otomasyonu kilitlememesi için kasıtlı).

_safecd_hist_file() {
    local dir="${XDG_DATA_HOME:-$HOME/.local/share}"
    # 'command' ile çağrılıyor: aşağıdaki mkdir fonksiyonumuzu değil,
    # gerçek sistem mkdir'ini çalıştırır - yoksa kendi kendini tetikleyip
    # gereksiz bir "içine girilsin mi?" sorusu çıkarırdı.
    command mkdir -p "$dir"
    echo "$dir/safecd_history"
}

cd() {
    local hist_file
    hist_file="$(_safecd_hist_file)"
    touch "$hist_file"

    # -h / --history : geçmişi numaralı göster
    if [[ "${1:-}" == "-h" || "${1:-}" == "--history" ]]; then
        if [[ ! -s "$hist_file" ]]; then
            echo "(cd geçmişi boş)"
            return 0
        fi
        nl -ba -w4 -s'  ' "$hist_file"
        return 0
    fi

    # N! : geçmişteki N numaralı dizine git
    if [[ "${1:-}" =~ ^[0-9]+!$ ]]; then
        local num="${1%!}"
        local target
        target=$(sed -n "${num}p" "$hist_file")
        if [[ -z "$target" ]]; then
            echo "cd: geçmişte $num numaralı kayıt yok" >&2
            return 1
        fi
        builtin cd -- "$target" || return $?
        [[ "$PWD" != "$(tail -n1 "$hist_file" 2>/dev/null)" ]] && echo "$PWD" >> "$hist_file"
        return 0
    fi

    # normal kullanım: her şeyi olduğu gibi gerçek builtin cd'ye devret
    builtin cd "$@"
    local rc=$?
    if (( rc == 0 )); then
        [[ "$PWD" != "$(tail -n1 "$hist_file" 2>/dev/null)" ]] && echo "$PWD" >> "$hist_file"
    fi
    return $rc
}

mkdir() {
    # Gerçek mkdir'i çağır - tüm bayraklar/davranış birebir korunur
    command mkdir "$@"
    local rc=$?
    (( rc == 0 )) || return $rc

    # Sadece bir terminaldeysek (otomasyonu kilitlememek için) devam et
    [[ -t 0 ]] || return 0

    # '-' ile başlamayan argümanları hedef dizin say (-m/--mode değerini atla)
    local -a dirs=()
    local skip_next=0 arg
    for arg in "$@"; do
        if (( skip_next )); then
            skip_next=0
            continue
        fi
        case "$arg" in
            -m|--mode) skip_next=1 ;;
            -*) ;;
            *) dirs+=("$arg") ;;
        esac
    done

    # Yalnızca TEK bir dizin oluşturulduysa sor
    if (( ${#dirs[@]} == 1 )); then
        local target="${dirs[0]}"
        local reply
        read -r -p "Dizin içine girilsin mi? ($target) (y/n) " reply
        case "$reply" in
            y|Y|e|E) builtin cd -- "$target" ;;
            *) : ;;
        esac
    fi
}
