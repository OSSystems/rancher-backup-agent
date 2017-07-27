.Container as $parent | select($parent.labels | .["br.com.ossystems.rancher.backup.driver"]) | $parent
