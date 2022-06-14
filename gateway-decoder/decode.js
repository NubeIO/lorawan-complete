const readline = require('readline');
const lora_packet = require("lora-packet");
const yargs = require('yargs/yargs')
const { hideBin } = require('yargs/helpers')

const argv = yargs(hideBin(process.argv))
  .option('json', {
    alias: 'j',
    description: 'Output unformatted JSON (useful for piping).'
  })
  .parse()
var counter = 1

function asHexString(buffer) {
  return buffer.toString("hex").toUpperCase();
}

const stdin = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

stdin.on('line', function(line){
    if (line.indexOf('rxpk') <= 0) {
        return
    }
    const json_full = JSON.parse(line.substring(line.indexOf('{')).trim())
    const j = json_full.rxpk[0]
    const packet = lora_packet.fromWire(Buffer.from(j.data, "base64"));
    // console.log(packet.toString());
    var output = {}
    output.freq = j.freq
    output.datarate = j.datr
    output.rssi = j.rssi
    output.snr = j.lsnr
    output.MessageType = packet.getMType()

    if (packet.isJoinRequestMessage()) {
        output.DevEUI = asHexString(packet.DevEUI)
    } else if (packet.isDataMessage()) {
        output.DevAddr = asHexString(packet.DevAddr)
    }

    if (argv.json) {
        console.log(JSON.stringify(output, null, 0))
    } else {
        console.log("Rx", counter)
        console.log(output)
        console.log()
    }
    counter++
})
