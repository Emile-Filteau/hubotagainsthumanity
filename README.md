# hubot-hubotagainsthumanity

A hubot script that offers a set of commands to play Cards Against Humanity

See [`src/hubotagainsthumanity.coffee`](src/hubotagainsthumanity.coffee) for full documentation.

See [https://github.com/isra17/hubot-against-humanity-backend](https://github.com/isra17/hubot-against-humanity-backend) for backend server

## Installation

In hubot project repo, run:

`npm install hubot-hubotagainsthumanity --save`

Then add **hubot-hubotagainsthumanity** to your `external-scripts.json`:

```json
["hubot-hubotagainsthumanity"]
```

You need to add 3 environment variables to run this script :

HAH_GAME_CHANNEL   : Channel name for interaction with the game

HAH_SERVER_ADDRESS : Backend Server Address

HAH_SECRET         : Shared secret with the backend server so you can actually make requests

## Sample Interaction

```
user1>> hah join
hubot>> user1 joined the game
user1>> hah play 4
hubot>> you played a card
```
