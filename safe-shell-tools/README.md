# safe-shell-tools

Günlük kullanılan dört Bash komutunu (`rm`, `cd`, `mkdir`, `ls`) gerçek
davranışlarını olabildiğince birebir koruyarak biraz daha güvenli ve
kullanışlı hale getiren küçük bir araç seti.

- **`rm`** → silinen her şey 5 dakikalık bir geri alma penceresine girer, gerçekten silinmez
- **`undelete`** → o pencere içindeyken dosyaları eski konumuna geri getirir
- **`cd`** → gidilen her dizini numaralı bir geçmişte tutar, numarayla geri dönebilirsin
- **`mkdir`** → oluşturduğun dizinin içine girmek isteyip istemediğini sorar
- **`ls`** → `--tree` (ağaç görünümü) ve `--age` (dosya yaşı) bayrakları ekler

Her ikisi dışındaki tüm normal kullanım (bayraklar, çoklu dosya, vs.)
olabildiğince orijinal komutlarla birebir aynı şekilde çalışır.

## Neden bazıları script, bazıları fonksiyon?

Bu, gözden kaçırılmaması gereken önemli bir mimari ayrım:

| Komut | Nasıl uygulanıyor | Neden |
|---|---|---|
| `rm`, `ls` | `~/.local/bin` içine konan gerçek çalıştırılabilir dosyalar | Sadece dosya okuyup/yazıyorlar, shell'in durumunu değiştirmeleri gerekmiyor |
| `cd`, `mkdir` | `~/.bashrc`'ye **source edilen** Bash fonksiyonları | Shell'in bulunduğu dizini değiştirmek zorundalar |

`cd`, Bash'in kendi içinde tanımlı bir **builtin**'dir çünkü bir alt process
(yani ayrı bir program/script) kendi ebeveyn shell'inin çalışma dizinini asla
değiştiremez - bu bizim script'imizin bir eksikliği değil, Unix
process'lerinin temel bir kuralı. Aynı sebeple `mkdir`'in "oluşturduğun
dizine gir" özelliği de bir fonksiyon olmak zorunda. Bu yüzden `cd` ve
`mkdir`, `rm`/`ls` gibi PATH'e konan birer dosya değil, doğrudan sizin
interaktif terminal oturumunuzun içine tanımlanan birer fonksiyondur.

Pratik sonucu: `rm`/`ls` her yerde (başka scriptler dahil, eğer o scriptler
bu PATH'i kullanıyorsa) devreye girebilirken, `cd`/`mkdir` SADECE
`~/.bashrc`'yi source eden interaktif terminalinizde çalışır - başka bir
scriptin içinden çağrılan `mkdir`/`cd` bundan etkilenmez.

## Kurulum

### Otomatik (önerilen)

```bash
git clone <bu-repo-url> safe-shell-tools
cd safe-shell-tools
./install.sh
source ~/.bashrc
```

### Elle

```bash
# rm ve ls
mkdir -p ~/.local/bin
cp bin/saferm ~/.local/bin/saferm
cp bin/safels ~/.local/bin/safels
chmod +x ~/.local/bin/saferm ~/.local/bin/safels
ln -sf ~/.local/bin/saferm ~/.local/bin/rm
ln -sf ~/.local/bin/saferm ~/.local/bin/undelete
ln -sf ~/.local/bin/safels ~/.local/bin/ls

# cd ve mkdir
mkdir -p ~/.local/share/safe-shell-tools
cp shell/safe-shell-functions.sh ~/.local/share/safe-shell-tools/

# ~/.bashrc dosyanın SONUNA ekle:
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
echo 'source "$HOME/.local/share/safe-shell-tools/safe-shell-functions.sh"' >> ~/.bashrc

source ~/.bashrc
```

### Doğrulama

```bash
which rm     # ~/.local/bin/rm göstermeli, /usr/bin/rm DEĞİL
which ls     # ~/.local/bin/ls göstermeli
type cd      # "cd is a function" göstermeli
type mkdir   # "mkdir is a function" göstermeli
```

## Kullanım

### rm / undelete

```bash
rm dosya.txt              # normal rm gibi görünür, aslında çöpe taşınır
rm -rf klasor/             # -r, -f, -v, -i hepsi destekleniyor
rm -s dosya1 dosya2        # TEST MODU - hiçbir şeyi silmez, sadece önizler:
                           #   dosya1
                           #   dosya2
                           #   Toplam: 2 dosya
                           #   Gerçek işlem YAPILMADI

undelete                   # çöp kutusunu listeler (kalan süreyle birlikte)
undelete last              # en son silineni geri getirir
undelete <id>              # belirli bir kaydı geri getirir
undelete dosya.txt         # isme göre eşleşen kaydı geri getirir
undelete --all             # çöpteki her şeyi geri getirir
```

Geri alma penceresi **5 dakika**. Süre dolunca arka planda otomatik olarak
kalıcı silinir. Aynı isimde birden fazla silme yapılırsa (çakışma), geri
getirilirken orijinal isim doluysa `isim.restored-<zaman>` olarak geri
gelir - veri asla üzerine yazılmaz.

### cd

```bash
cd bir/yol          # normal cd - hiçbir şey değişmedi
cd -                # normal cd - (önceki dizine dön), aynen çalışır
cd -h               # ya da: cd --history
                    #    1  /home/kullanici/projeler
                    #    2  /home/kullanici/projeler/api
                    #    3  /tmp
cd 2!               # geçmişteki 2 numaralı dizine gider
```

### mkdir

```bash
mkdir yeni-proje
# çıktı: Dizin içine girilsin mi? (yeni-proje) (y/n)
# y -> içine girer, n -> girmez, olduğun yerde kalırsın

mkdir -p a/b/c       # -p ile de çalışır, sorulan dizin en derindeki (c) olur
mkdir a b c          # birden fazla dizin verilirse HİÇ SORMAZ (belirsizlik olmasın diye)
```

### ls

```bash
ls --tree            # geçerli dizini ağaç şeklinde gösterir
ls --tree -a         # gizli dosyalar dahil
ls --tree bir/yol    # belirtilen dizin için

ls --age             # dosyaların "3 gün önce" gibi okunabilir yaşını gösterir

ls -la               # bunların dışındaki HER ŞEY normal ls gibi çalışır
```

## Bilinen sınırlar

- `rm`/`ls` koruması yalnızca komut PATH üzerinden düz isimle çağrıldığında
  devreye girer. Bir programın doğrudan `/usr/bin/rm` çağırması bundan
  etkilenmez (bu kasıtlı - sistem betikleri bozulmasın diye).
- `cd` geçmişi `~/.local/share/safecd_history` dosyasında sınırsız büyür,
  istersen elle temizleyebilirsin.
- `mkdir`'in "içine gir mi" sorusu yalnızca bir terminalden (TTY) çağrıldığında
  sorulur; bir script içinden çağrılırsa sessizce atlanır (otomasyonu
  kilitlememesi için kasıtlı).
- Farklı bir dosya sistemine (örn. ayrı bir disk) taşınan çok büyük dosyalarda
  `rm`'in çöpe taşıması normalden yavaş olabilir (mv, aynı dosya sisteminde
  anlık "rename" yaparken, farklı dosya sisteminde kopyala+sil yapmak zorunda).
- `ls --tree` ve `ls --age` şu an aynı anda kullanılamıyor (biri diğerini
  geçersiz kılar, `--tree` öncelikli).

## Lisans

Bu repo'yu paylaşırken bir lisans eklemek istersen (örn. MIT), GitHub'ın
repo oluşturma ekranındaki "Add a license" seçeneğini kullanabilirsin.
