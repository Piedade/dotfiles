# Mostra todas as funções disponíveis nos scripts ~/.dotfiles/.bash/*.sh
help(){
    local filter="$1"

    # cada entrada: "ficheiro.sh :: nome_da_funcao :: descrição"
    local -a FUNCS=(
        "0_utils.sh :: echo_error :: Imprime mensagem de erro a negrito e vermelho"
        "0_utils.sh :: echo_success :: Imprime mensagem de sucesso a negrito e verde"
        "0_utils.sh :: echo_info :: Imprime mensagem informativa a negrito e amarelo"
        "0_utils.sh :: echo_prestashop :: Imprime mensagem com ícone e cor do PrestaShop"
        "0_utils.sh :: echo_laravel :: Imprime mensagem com ícone e cor do Laravel"
        "0_utils.sh :: echo_wordpress :: Imprime mensagem com ícone e cor do WordPress"
        "0_utils.sh :: check_permission :: Mostra as permissões (chmod) de um ficheiro ou pasta"
        "0_utils.sh :: gen_pass :: Gera uma password aleatória de 20 carateres"
        "0_utils.sh :: run_remote :: Corre um comando via SSH numa conta e termina a sessão se falhar"
        "0_utils.sh :: select_account :: Escolhe uma conta cPanel via fzf a partir do servidor"
        "0_utils.sh :: setup_ssh_key :: Copia a chave SSH pública para authorized_keys de uma conta"

        "10_direnv.sh :: setup_direnv :: Cria symlinks de PHP/Composer e ativa a versão de Node via nvm"
        "10_direnv.sh :: create_envrc :: Gera um .envrc com PHP/Node/Composer detetados e ativa o direnv"

        "apache.sh :: create_domain :: Cria vhost Apache, pasta em /var/www e certificado mkcert"
        "apache.sh :: fix_permissions :: Aplica permissões corretas a um projeto Laravel/PrestaShop local"

        "compress.sh :: compress :: Comprime uma pasta para .tar.zst usando todos os núcleos (zstd -T0)"

        "cpanel.sh :: change_cpanel_password :: Gera nova password cPanel via WHM e mostra dados de acesso"

        "dns.sh :: get_dns :: Mostra os registos DNS de um domínio (A, MX, TXT, etc.)"
        "dns.sh :: check_spf :: Verifica o SPF de um domínio e testa se um IP pode enviar emails"
        "dns.sh :: check_dmarc :: Verifica o registo DMARC de um domínio e a sua política"
        "dns.sh :: check_dkim :: Procura o registo DKIM de um domínio testando selectores comuns"
        "dns.sh :: check_spam :: Corre SPF, DKIM e DMARC seguidos para um domínio"

        "DS_Store.sh :: delete_DS_Store :: Apaga recursivamente ficheiros .DS_Store de uma pasta"

        "emails.sh :: select_domain :: Devolve o domínio principal (DNS) de uma conta cPanel"
        "emails.sh :: select_domain_global :: Escolhe um domínio via fzf entre todos os do servidor"
        "emails.sh :: check_shell_access :: Verifica se a conta tem shell bash, precisa ativar ou não existe"
        "emails.sh :: add_shell_access :: Ativa o acesso shell bash de uma conta via chsh"
        "emails.sh :: create_email :: Cria uma conta de email cPanel e mostra as credenciais de acesso"

        "fonts.sh :: convert_ttf_woff2 :: Converte todos os .ttf da pasta atual para .woff2"

        "github.sh :: zipLastCommitFiles :: Cria um .tgz com os ficheiros alterados no último commit"

        "image.sh :: resize :: Redimensiona imagens com ImageMagick, guardando originais em _original"
        "image.sh :: to_webp :: Converte JPG/PNG da pasta atual para WebP com qualidade configurável"
        "image.sh :: create_favicon :: Gera um favicon.ico multi-tamanho a partir de uma imagem"
        "image.sh :: crop_svg :: Recorta um SVG à área de desenho usando o Inkscape"
        "image.sh :: upscale :: Aumenta a resolução de imagens com realesrgan-ncnn-vulkan"

        "mysql.sh :: get_database :: Descarrega e importa localmente uma BD de produção, convertendo-a para .test"

        "odoo.sh :: build_odoo_module :: Empacota um módulo Odoo em .tar.gz, excluindo node_modules/cache"
        "odoo.sh :: get_odoo_filestorage :: Sincroniza (rsync, só leitura) o filestore de um staging dev.odoo.com para local"
        "odoo.sh :: get_odoo_database :: Sincroniza (pg_dump, só leitura) a BD de um staging dev.odoo.com para a BD local 'red'"

        "pdf.sh :: merge_pdf :: Junta vários PDFs num só ficheiro com o Ghostscript"

        "prestashop.sh :: create_prestashop :: Cria de raiz uma loja PrestaShop numa conta cPanel (build, BD, install, email)"
        "prestashop.sh :: detect_ps_php_bin :: Deteta o binário PHP correto de um site local a partir do vhost Apache"
        "prestashop.sh :: detect_ps_version :: Deteta a versão instalada do PrestaShop (via BD ou código-fonte)"
        "prestashop.sh :: update_prestashop :: Atualiza um PrestaShop local para a versão mais recente (Update Assistant)"
        "prestashop.sh :: uninstall_ps_modules :: Desinstala módulos de um PrestaShop local via CLI, sem backoffice"
        "prestashop.sh :: generate_secrets :: Regenera as chaves/segredos de segurança do parameters.php"
        "prestashop.sh :: is_a_prestashop_project :: Verifica se a pasta atual é um projeto PrestaShop (composer.lock)"
        "prestashop.sh :: create_ps_module :: Cria um novo módulo PrestaShop a partir de um template"

        "ps_ce.sh :: sync_ce_tables :: Envia as tabelas ps_ce_* da BD local para a produção (sobrescreve remoto)"

        "qrcode.sh :: create_qrcode :: Gera um QR code (PNG e SVG) para um URL"

        "server.sh :: remove_shell_access :: Remove o acesso shell de uma conta remota (define noshell)"
        "server.sh :: check_php_extensions :: Confirma que uma conta tem as extensões PHP indicadas carregadas"
        "server.sh :: remote_file_exists :: Verifica se um caminho existe na home de uma conta remota"
        "server.sh :: mysql_database_exists :: Verifica se uma base de dados já existe numa conta cPanel"
        "server.sh :: mysql_user_exists :: Verifica se um utilizador MySQL já existe numa conta cPanel"
        "server.sh :: server :: Ativa shell/SSH se preciso e liga por SSH à conta indicada no servidor"
        "server.sh :: connect_server :: Liga por SSH a uma conta específica no servidor de produção"
        "server.sh :: echo_production_warning :: Pede confirmação antes de qualquer deploy para produção"

        "site.sh :: get_site_files :: Sincroniza ficheiros de um site de produção para a pasta local via rsync"

        "staging.sh :: clone_to_staging :: Clona um site de produção (ficheiros + BD) para staging.<domínio> — também serve para rebuild de staging já existente"

        "whm.sh :: whm_account_by_domain :: Devolve a conta cPanel dona de um domínio via WHM API"
        "whm.sh :: whm_docroot_by_domain :: Devolve o documentroot de um domínio via WHM API"
        "whm.sh :: check_domain :: Mostra a conta cPanel dona de um domínio (ou os NS se não encontrado)"

        "vite.sh :: deploy_laravel :: Builda e envia os assets Vite (public/build) de um projeto Laravel local para a conta cPanel, detetando conta/domínio automaticamente"

        "wireguard.sh :: wireguard_add_user :: Cria um novo peer WireGuard (servidor + ficheiros locais) com o próximo IP livre"

        "wordpress.sh :: create_wordpress :: Cria de raiz um site WordPress numa conta cPanel (BD, install, plugins, email)"

        "youtube.sh :: get_youtube :: Descarrega um vídeo do YouTube em mp4 (melhor qualidade) com yt-dlp"
    )

    echo -e "${BOLD}Funções disponíveis em ~/.dotfiles/.bash/${RESET}"
    [ -n "$filter" ] && echo_info "Filtro: ${filter}"
    echo

    local last_file="" printed_any=0
    local entry file fn desc
    for entry in "${FUNCS[@]}"; do
        file="${entry%% :: *}"
        entry="${entry#* :: }"
        fn="${entry%% :: *}"
        desc="${entry#* :: }"

        if [ -n "$filter" ] && [[ "$fn" != *"$filter"* && "$file" != *"$filter"* && "$desc" != *"$filter"* ]]; then
            continue
        fi

        if [ "$file" != "$last_file" ]; then
            echo -e "${BOLD}${CYAN}${file}${RESET}"
            last_file="$file"
        fi
        printf "  %-28s %s\n" "$fn" "$desc"
        printed_any=1
    done

    if [ "$printed_any" -eq 0 ]; then
        echo_error "Nenhuma função encontrada para \"${filter}\""
    fi
}
