# LIMA Sistemas Contra Incêndio

Plataforma interna de clientes, laudos, serviços, documentos e orçamentos.

## Instalação rápida

1. Abra o Supabase e entre no projeto `qlmvrafogyzvcruhvdzt`.
2. Vá em **SQL Editor > New query**.
3. Cole todo o conteúdo de `supabase-setup.sql` e clique em **Run**.
4. Vá em **Authentication > Users > Add user** e crie:
   - E-mail: `limasistemaofc@gmail.com`
   - Senha temporária: a senha definida pelo proprietário.
   - Marque o e-mail como confirmado.
5. Volte ao SQL Editor, execute somente o bloco **PROMOVER PRIMEIRO ADMINISTRADOR** existente no final do arquivo SQL.
6. No GitHub, envie `index.html` e `logo-lima.png` para a raiz do repositório `viniciuscastaginejs/sistema-lima`.
7. Em **Settings > Pages**, selecione **Deploy from a branch**, branch `main`, pasta `/root`.
8. No Supabase, abra **Authentication > URL Configuration** e informe:
   - Site URL: `https://viniciuscastaginejs.github.io/sistema-lima/`
   - Redirect URL: `https://viniciuscastaginejs.github.io/sistema-lima/**`

## Segurança

- Nunca coloque `service_role`, senha do banco ou JWT secret no HTML.
- A chave presente no HTML é publicável e protegida pelas políticas RLS.
- Troque a senha temporária após o primeiro acesso.
- Novos usuários ficam pendentes até aprovação do administrador.

## Uso

O botão **Tutorial** dentro do sistema apresenta o passo a passo. Em **Usuários**, o administrador cria e aprova funcionários. Em **Orçamentos**, é possível salvar, duplicar e imprimir em PDF.
