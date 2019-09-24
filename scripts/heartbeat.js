const request = require('request')
const makeyId = "be816a9d-3967-48a7-8810-abbbed51b3bf"

setInterval(function(){
  request.get('http://social.mrmakeit.me:8000/'+makeyId+'/heartbeat',function(err){
    if(err){
      console.log("Couldn't connect to heartbeat server.")
    }
  })
},3000);

