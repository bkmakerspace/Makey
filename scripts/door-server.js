
module.exports = (robot) => {

  class DoorAccess {
    userWithBadge(badgeId) {
      for(var key in robot.brain.data.users) {
        if(hasBadge(user, badgeId)) {
          return user;
        }
      }
      return null;
    }

    hasBadge(user, badgeId) {
      const userBadges = this.userBadges(badgeId)
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
      userBadges = []
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

  robot.router.get('/door/:badgeId', (req, res) => {
    const user = robot.doorAccess.userWithBadge(req.params.badgeId);

    if(user && badgeId) {
      console.log("badge valid!")
      res.send(`${user.real_name}\nWELCOME!`);
      return;
    } else if (robot.brain.get("newBadgeUser") && badgeId) {
      const userToAdd = robot.brain.userForId(robot.brain.get("newBadgeUser"));
      robot.brain.set("newBadgeUser", null);
      userToAdd.badges = userToAdd.badges || [];
      userToAdd.badges.push(req.params.badgeId);
      res.send(`${user.real_name}\nBADGE ADDED!`);
      return;
    } else {
      const msg = "badge " +req.params.badgeId+ " not found!";
      console.log("failure:", msg);
      res.status(401);
      res.send(msg);
    }
  });
}
