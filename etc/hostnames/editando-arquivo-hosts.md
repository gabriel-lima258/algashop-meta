# Editando o arquivo hosts

## Windows

### Localização do arquivo

```
C:\Windows\System32\drivers\etc\hosts
```

### Passo a passo

1. Abra o Bloco de Notas como Administrador (clique com o botão direito → **Executar como administrador**).
2. No menu **Arquivo → Abrir**, navegue até o caminho acima.
3. Altere o filtro de arquivos para **Todos os arquivos**.
4. Abra o arquivo `hosts`.
5. Adicione as entradas ao final do arquivo.
6. Salve o arquivo.

> **Observação crítica:** No Windows, a falta de privilégios administrativos é a causa mais comum de falha ao salvar o arquivo.

---

## macOS

### Localização do arquivo

```
/etc/hosts
```

### Passo a passo

1. Abra o **Terminal**.
2. Execute o comando:

   ```
   sudo nano /etc/hosts
   ```

3. Informe sua senha de usuário.
4. Adicione as entradas ao final do arquivo.
5. Salve pressionando `CTRL + O` e confirme.
6. Saia com `CTRL + X`.

### Consideração técnica

O macOS utiliza cache de DNS. Em alguns casos, pode ser necessário limpá-lo para que as alterações tenham efeito imediato:

```
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
```

---

## Linux

### Localização do arquivo

```
/etc/hosts
```

### Passo a passo

1. Abra um terminal.
2. Execute:

   ```
   sudo nano /etc/hosts
   ```

   (ou substitua `nano` por `vim`, se preferir).
3. Insira as entradas desejadas.
4. Salve o arquivo e feche o editor.
