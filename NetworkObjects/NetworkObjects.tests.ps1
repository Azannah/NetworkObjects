#
# This is a PowerShell Unit Test file.
# You need a unit test framework such as Pester to run PowerShell Unit tests. 
# You can download Pester from http://go.microsoft.com/fwlink/?LinkID=534084
#

Import-Module "C:\Users\matth\Source\GitHub\NetworkObjects\NetworkObjects\NetworkObject.psm1"

Describe "Build-NetworkMap" {
	Context "Given a valid json file" {
		It "Should build a map" {
		  Build-NetworkMap -Path "C:\Users\matth\Source\GitHub\NetworkObjects\NetworkObjects\Resources\Nodes.json"
		}
	}
}