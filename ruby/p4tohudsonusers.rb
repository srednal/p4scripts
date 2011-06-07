#!/usr/bin/env ruby


require 'perforce'
require 'FileUtils'

p4 = P4.new

p4.users_INFO.each do |userdesc|
    # userdesc is: root <wls-infra_us@oracle.com> (Robert Oot) accessed 2009/12/10

    usrdata = userdesc.scan(/^(\S+)\s+<([^>]+)>\s+\(([^)]*)\).*$/)
    unless usrdata.nil? then
        uid, email, name = usrdata.flatten
        FileUtils.mkdir_p("users/#{uid}")
        File.open("users/#{uid}/config.xml", 'w') do |f|
            f.write <<EOF
<?xml version='1.0' encoding='UTF-8'?>
<user>
  <fullName>#{name}</fullName>
  <description>p4 user #{uid}</description>
  <properties>
    <hudson.tasks.Mailer_-UserProperty>
      <emailAddress>#{email}</emailAddress>
    </hudson.tasks.Mailer_-UserProperty>
  </properties>
</user>
EOF
        end
    end
end