#!/bin/bash

# Инициализируем конфигурационный сервер
docker exec -i configSrv mongosh --port 27017 --quiet <<EOF
rs.initiate(
  {
    _id : "config_server",
       configsvr: true,
    members: [
      { _id : 0, host : "configSrv:27017" }
    ]
  }
);
EOF

# Инициализируем первую шард реплику сет
docker exec -i shard1-1 mongosh --port 27010 --quiet <<EOF
rs.initiate(
    {_id: "rs0", members: [
      {_id: 0, host: "shard1-1:27010"},
      {_id: 1, host: "shard1-2:27011"},
      {_id: 2, host: "shard1-3:27012"}
    ]
  }
);
EOF

# Инициализируем вторую шард реплику сет
docker exec -i shard2-1 mongosh --port 27013 --quiet <<EOF
rs.initiate(
    {_id: "rs1", members: [
      {_id: 3, host: "shard2-1:27013"},
      {_id: 4, host: "shard2-2:27014"},
      {_id: 5, host: "shard2-3:27015"}
    ]
  }
);
EOF

# Инициализируем роутер, добавляем шарды, создаем бд и коллекцию с шардированием
docker exec -i mongos_router mongosh --port 27020 --quiet <<EOF
sh.addShard( "rs0/shard1-1:27010,shard1-2:27011,shard1-3:27012");
sh.addShard( "rs1/shard2-1:27013,shard2-2:27014,shard2-3:27015");
sh.enableSharding("somedb");
sh.shardCollection("somedb.helloDoc", { "name" : "hashed" } );
use somedb;
for(var i = 0; i < 1000; i++) db.helloDoc.insert({age:i, name:"ly"+i});
db.helloDoc.countDocuments();
EOF

# Проверяем что данные распределились по шардам
docker exec -i shard1-1 mongosh --port 27010 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF

docker exec -i shard2-1 mongosh --port 27013 --quiet <<EOF
use somedb;
db.helloDoc.countDocuments();
EOF
