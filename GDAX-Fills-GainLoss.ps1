##################################################################################################################################
# Name: GDAX-Fills-GainLoss.ps1                                                                                                  #
# Date Written: 04/10/18                                                                                                         #
# Written By: @weedoveropaites (Twitter)                                                                                         #
# Usage: Run ./GDAX-fills.ps1 from the same folder as your fills.csv file, which it uses for input. When the script completes it #
#        will output a file called fills-out.csv with a new column titled gainloss. It will show your gain or loss for each sell #
#        line. You can total that column for the total gains/losses, but the script will also display the total on the screen.   #
#        If you receive a message that it cannot run because of the Execution Policy, see the *NOTE* below.                      #
#                                                                                                                                #
# This PowerShell script is designed to convert a GDAX fills.csv exported file into gains and losses using the First In First    #
# Out (FIFO) accounting method. If your exported fills file from GDAX is missing buys that were transfered in from other places  #
# like Coinbase, you will need to insert a line at the appropriate time into the CSV that contains at least the following        #
# information: side (BUY if transfered in and SELL if transfered out), size (the quantity of coin transfered in or out), and     #
# price (the price per coin the transfer was bought or sold at when aquiried or spent). If you do not have enough coins to sell  #
# when it processes a SELL line, then you will receive an error and the script will terminate; this may be likely if coins were  #
# bought somewhere other than GDAX (including Coinbase) and transfered into GDAX to sell. If you have any questions contact the  #
# creator via the above Twitter handle.                                                                                          #
#                                                                                                                                #
# *NOTE* The script will require that you change the ExecutionPolicy of PowerShell to RemoteSigned. This can be done by first    #
# running PowerShell elevated (Run As Administrator), and running the command "Set-ExecutionPolicy RemoteSigned" and saying Yes  #
# to the warning. You can then run the script as a regular user, it must be run in the same folder as fills.csv.                 #
#                                                                                                                                #
# GDAX-Fills.ps1 is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License as #
# published by the Free Software Foundation, either version 3 of the License, or any later version.                              #
#                                                                                                                                #
# GDAX-Fills.ps1 is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty  #
# of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details                    #
# (http://www.gnu.org/licenses/).                                                                                                #
##################################################################################################################################

$q = New-Object System.Collections.Queue
$currentsell = New-Object -TypeName PSObject
Add-Member -InputObject $currentsell -Name quantity -MemberType NoteProperty -Value 0
Add-Member -InputObject $currentsell -Name price -MemberType NoteProperty -Value 1
$remainder = New-Object -TypeName PSObject
Add-Member -InputObject $remainder -Name remainder -MemberType NoteProperty -Value 0
Add-Member -InputObject $remainder -Name gainsofar -MemberType NoteProperty -Value 0

$totalgain = 0

$fills = Import-Csv fills.csv | Select-Object *,@{Name='gainloss';Expression={$null}}

foreach ($line in $fills)
{
    if ($line.side -eq "BUY")
    {
        $newcoin = New-Object -TypeName PSObject
        Add-Member -InputObject $newcoin -Name quantity -MemberType NoteProperty -Value 0
        Add-Member -InputObject $newcoin -Name price -MemberType NoteProperty -Value 1
        $newcoin.price = $line.price
        $newcoin.quantity = $line.size
        $q.Enqueue($newcoin)
    } elseif ($line.side -eq "SELL")
    {
        if ($currentsell.quantity -eq 0) 
        {
            try
            {
                $currentsell = $q.Dequeue()
            } catch
            {
                Write-Host "You are trying to sell more coins than you have available" -ForegroundColor Red
                Write-Host "Caught an exception on the following SELL line:" -ForegroundColor Red
                Write-Host $line -ForegroundColor Red
                exit
            }
        }
        if ($currentsell.quantity -ge $line.size)
        {
            $currentsell.quantity = $currentsell.quantity - $line.size
            $line.gainloss = ($line.price - $currentsell.price) * $line.size
        } else
        {
            $remainder.remainder = $line.size
            $remainder.gainsofar = 0
            do
            {
                if ($remainder.remainder -ge $currentsell.quantity)
                {
                    $remainder.remainder = $remainder.remainder - $currentsell.quantity
                    $remainder.gainsofar = $remainder.gainsofar + (($line.price - $currentsell.price) * $currentsell.quantity)
                    $currentsell.quantity = 0
                    try
                    {
                        $currentsell = $q.Dequeue()
                    } catch
                    {
                        Write-Host "You are trying to sell more coins than you have available" -ForegroundColor Red
                        Write-Host "Caught an exception on the following SELL line:" -ForegroundColor Red
                        Write-Host $line -ForegroundColor Red
                        exit
                    }
                } else
                {
                    $currentsell.quantity = $currentsell.quantity - $remainder.remainder
                    $remainder.gainsofar = $remainder.gainsofar + (($line.price - $currentsell.price) * $remainder.remainder)
                    $remainder.remainder = 0
                }
            } until ($remainder.remainder -eq 0)
            $line.gainloss = $remainder.gainsofar
        }
    $totalgain = $totalgain + $line.gainloss
    }
}
$ttlrnd = [math]::Round($totalgain,2)
"Total Gain or Loss: " + $ttlrnd
$fills | Export-Csv -Path fills-out.csv
pause