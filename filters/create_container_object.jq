. as $parent |
  { id: $parent.id,
    driver: $parent.labels["br.com.ossystems.rancher.backup.driver"],
    name: $parent.name,
    ip: $parent.primaryIpAddress,
    env: $parent.environment,
    schedule: $parent.labels["br.com.ossystems.rancher.backup.schedule"]
  }
