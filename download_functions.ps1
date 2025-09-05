$PROJECT_ID = "oeiwnpngbnkhcismhpgs"

$FUNCTIONS = (supabase functions list | Select-Object -Skip 3) `
    | ForEach-Object { ($_ -split '\s+\|\s+')[1] } `
    | Where-Object { $_ -and ($_ -ne "NAME") }

foreach ($FUNCTION_NAME in $FUNCTIONS) {
    Write-Host "Downloading function: $FUNCTION_NAME"
    supabase functions download $FUNCTION_NAME --project-ref $PROJECT_ID --legacy-bundle
}
