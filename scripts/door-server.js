// Description:
//   Door controller for the Makerspace
// Commands:
//   hubot add badge to <user> - Add a badge to allow <user> to enter the space
//   hubot remove badges from <user> - Remove all existing badges for <user>
// Notes:
//   Adding and removing badges requires the 'door-admin' permission
//   from hubot-admin.  Adding badges will use the door sensor to get the badge
//   id.
// Author:
//   pipakin
const crypto = require('crypto')
module.exports = (robot) => {

  class DoorAccess {
    userWithBadge(badgeId) {
      let door = this
      for(var key in robot.brain.data.users) {
        if(door.hasBadge(robot.brain.data.users[key], badgeId)) {
          return key;
        }
      }
      return null;
    }

    hasBadge(user, badgeId) {
      let door = this
      const userBadges = door.userBadges(user)
      if(userBadges) {
        for(var badgeK in userBadges)
        {
          if(userBadges[badgeK] == badgeId)
            return true;
        }
      }
      return false;
    }

    userBadges(user) {
      let door = this
      let userBadges = []
      if(user.badges) {
        userBadges = userBadges.concat(user.badges);
      }

      return userBadges;
    }
  }

  robot.doorAccess = new DoorAccess();

  robot.respond(/add badge to @?(.*)/i, (msg) =>
  {
    const name = msg.match[1].trim();
    if(name.toLowerCase() === 'me') name = msg.message.user.name;

    const user = robot.brain.userForName(name)
    if(!user) {
      msg.reply(`user ${name} does not exist.`);
      return;
    }

    if(!robot.auth.hasRole(msg.message.user, "door-admin")) {
      msg.reply("Sorry, only door admins can add badges.");
      return;
    }

    robot.brain.set("newBadgeUser", user.id);
    msg.reply("Please swipe device now.");
  });

  robot.respond(/remove badges from @?(.*)/i, (msg) =>
  {
    const name = msg.match[1].trim();
    if(name.toLowerCase() === 'me') name = msg.message.user.name;

    const user = robot.brain.userForName(name)
    if(!user) {
      msg.reply(`user ${name} does not exist.`);
      return;
    }

    if(!robot.auth.hasRole(msg.message.user, "door-admin")) {
      msg.reply("Sorry, only door admins can remove badges.");
      return;
    }

    user.badges = [];
  });

  robot.router.get('/hubot/randomBytes', (req,res) => {
    crypto.randomBytes(16,(err,buf) => {
      if(err){
        res.status(400)
      }else{
        res.send(buf)
      }
    })
  })

  bodyText=function(req, res, next){
  if (req.is('text/*')) {
    req.text = '';
    req.setEncoding('utf8');
    req.on('data', function(chunk){ req.text += chunk });
    req.on('end', next);
  } else {
    next();
  }
  }
  robot.router.post('/door/:badgeId', bodyText, (req, res) => {
    console.log('new badge check')
    console.log(req.text)
    const user = robot.doorAccess.userWithBadge(req.params.badgeId);
    console.log(user)
    const secureUser = robot.doorAccess.userWithBadge(req.text);
    console.log(secureUser)
    const badgeId = req.params.badgeId;

    if(user && badgeId) {
      const userObject = robot.brain.userForId(user)
      console.log("old style entry!");
      userObject.badges = userObject.badges.filter(x => x != badgeId);
      if(!secureUser) {
        console.log("created new user.");
        userObject.badges.push(req.text);
      }
      res.send(`${userObject.real_name}\nBADGE UPDATED!`);
      robot.emit("doorUnlock", {
        'user': userObject,
        'badgeId': req.text
      })
      return;
    } else if(secureUser && req.text) {
      const userObject = robot.brain.userForId(secureUser)
      res.send(`${userObject.real_name}\nWELCOME!`);
      robot.emit("doorUnlock", {
        'user': userObject,
        'badgeId': req.text
      })
      return;
    } else if (robot.brain.get("newBadgeUser") && badgeId) {
      const userToAdd = robot.brain.userForId(robot.brain.get("newBadgeUser"));
      robot.brain.set("newBadgeUser", null);
      userToAdd.badges = userToAdd.badges || [];
      userToAdd.badges.push(req.text);
      res.send(`${userToAdd.real_name}\nBADGE ADDED!`);
      robot.emit("doorUnlock", {
        'user': userToAdd,
        'badgeId': req.text
      })
      return;
    } else {
      const msg = "badge " +req.params.badgeId+ "/" + req.text + " not found!";
      console.log("failure:", msg);
      res.status(401);
      res.send("ERROR\nBADGE ERROR");
    }
  });
}
