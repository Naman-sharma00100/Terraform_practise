// server.js
const express = require("express");
const app = express();

app.get("/user/:id", (req, res) => {
  const id = req.params.id;
  res.json({
    id,
    name: `John Doe #${id}`
  });
});

app.listen(80, () => {
  console.log("Server running on port 80");
});