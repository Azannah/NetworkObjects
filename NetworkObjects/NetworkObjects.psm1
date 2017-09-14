<#
	My Function
#>
function Build-NetworkMap {
  [CmdletBinding()]
  Param(
    [Parameter(
      HelpMessage="Path of folder or file containing network node descriptors in json format",
      Mandatory=$true,
      #ParameterSetName="embedded",
      Position=0,
      ValueFromPipeline=$false,
      ValueFromPipelineByPropertyName=$false,
      ValueFromRemainingArguments=$false)]
    #[Alias('FullName')]
    [ValidateScript({Test-Path $_})] #about_Functions_Advanced_Parameters
    [string]
    # The full path and name of the assembly to load (eg., "C:\Program Files\My Application\mylibrary.subnamespace.dll")
    $Path
  )

  begin {
    # json 
    [void][System.Reflection.Assembly]::LoadWithPartialName("System.Web.Extensions")
    $jsonSerializer = New-Object -TypeName System.Web.Script.Serialization.JavaScriptSerializer 
    $jsonFile =  Get-Content $Path

    function deserializeJsonFile ($jsonFile) {
      $jsonSerializer.MaxJsonLength = $jsonFile.Length
      
      try {
        $jsonObj = $jsonSerializer.DeserializeObject($jsonFile)
      } catch {
        Write-Error "Unable to deserialize specified file"
        break;
      }

      return $jsonObj
    }

  }

  process {
    
    $nodes = {}

    foreach($file in (Get-ChildItem $Path -Filter "*.json")) {
      $jsonNodes = deserializeJsonFile $file
    }

    $jsonNodes
  }
}



Export-ModuleMember -Function 'Build-*'