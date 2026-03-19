#!/bin/bash
mongo unifi --eval "
db.createUser({
  user: '${MONGO_USER}',
  pwd: '${MONGO_PASS}',
  roles: [
    { role: 'dbOwner', db: 'unifi' },
    { role: 'dbOwner', db: 'unifi_stat' },
    { role: 'dbOwner', db: 'unifi_audit' }
  ]
})
"
