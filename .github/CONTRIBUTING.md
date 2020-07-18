# Contributing

Pull request will be closed as soon as possible. Do not waste my time with opening any.

# How to write manifests

- [Recommended manifest format][Template]
- Observe blocks sequence and structure from [Template][Template]
- Naming
    - All manifests should use `PascalCase` with first uppercase character
        - Unless it's some programming related manifest
            - docker, blisk, pwsh, ...
- **ALWAYS** respect:
    - yml typed manifest, when it's supported
    - `yml` extension instead of `yaml`
    - `regex` instead of `re`
    - `jsonpath` instead of `jp`
    - Convert array with only 1 string into normal string
    - Description
        - Include app name at start
        - End with dot
            - `"App name. Meaningful description."`
    - Script Blocks (`installer.script`, `post_install`, `pre_install`)
        - Use literal (`|`) blocks instead of folded (`>`)
        - Escape path in script blocks
        - Indent code as you would normally do
- **YAML**
    - Use single quotes
    - Don't quote properties
    - Don't quote strings
        - Unless version is number (integer or float)
- License
    - Use url property if it's available
    - Use string only, if there is no available url
- Arrays
    - Indent arrays
- Bins and Shortcuts
    - Use Backslashes
    - Do not include `$dir`
    - Do not create bin for GUI applications
        - Unless GUI application have argument handler
            - vscode, DWT, ...
        - Only use bin for CLIs
- Persisting
    - Do not include `$dir`
    - If persising file does not exists after unpacking / installing
        - Use this block in `pre_install` or `installer.script`:
            - Available via vscode snippet: `persistCheck`

```yml
...
pre_install: |
# post_install
# installer.script : |
  # Creating default settings
  function CreateFile([String] $file, [String] $content = $null) {
    if (-not (Test-Path "$persist_dir\$file")) {
      Write-Host 'File' $file 'does not exists. Creating.' -f Yellow
      Set-Content "$dir\$file" $content -Encoding Ascii
   }
```

[Template]: ../.vscode/Template.yml
