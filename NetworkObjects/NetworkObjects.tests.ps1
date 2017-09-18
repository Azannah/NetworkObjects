#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

# Get working path depending on location - there's got to be a better way to do this...
#$my_pwd = $env:HOMEPATH
#$my_pwd = "repos", "GitHub" | ? { Test-Path "$pwd\source\$_" } | %{ "$pwd\source\$_\NetworkObjects\NetworkObjects" }

#Import-Module "$PWD\NetworkObjects\NetworkObjects.psm1"
Import-Module "C:\Users\matth\Source\GitHub\NetworkObjects\NetworkObjects\NetworkObjects.psm1"

Describe "Build-NetworkMap" {
	Context "Given a valid json file" {
		It "Should build a map" {
		  #Build-NetworkMap -Path "$PWD\NetworkObjects\Resources\Nodes.json"
      Build-NetworkMap -Path "C:\Users\matth\Source\GitHub\NetworkObjects\NetworkObjects\Resources\Nodes.json"
		}
	}
}