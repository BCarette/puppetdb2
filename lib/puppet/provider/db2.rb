require 'puppet/provider'

class Puppet::Provider::Db2 < Puppet::Provider

  # db2_exec.
  # This method calls the db2 command located under the install_root
  # directory and runs it in the correct DB2 instance by setting the
  # DB2INSTANCE environment variable.
  #
  def db2_instance_exec(command, failonfail=true, user=nil)
    envhash = { "DB2INSTANCE" => @resource[:instance]}
    rootdir = @resource[:install_root]
    executable = File.join(rootdir, 'bin', 'db2')

    command = [ executable, command ].flatten.join(" ")

    self.debug("Using custom environment #{envhash}")
    exec_db2_command(command, envhash, failonfail, user=user)
  end

  def db2_exec(*args)
    db2_instance_exec(args.flatten.join(" "))
  end

  def db2_exec_nofail(*args)
    db2_instance_exec(args.flatten.join(" "), false)
  end

  def db2_exec_instance_user(*args)
    db2_instance_exec(args.flatten.join(" "), true, @resource[:instance])
  end

  def db2_exec_instance_user_nofail(*args)
      db2_instance_exec(args.flatten.join(" "), false, @resource[:instance])
  end

  def exec_db2_command(command,envhash = {}, failonfail=true, user=nil)
    output = Puppet::Util::Execution.execute(
      command,
      :failonfail => failonfail,
      :custom_environment => envhash,
      :uid => user.nil?  ? nil : Etc.getpwnam(user).uid,
    )
  end

  # This is needed to refresh the cache after adding or removing things
  # from the catalog configuration
  #
  def db2_terminate
    db2_exec('terminate')
  end

  # The flush method will be called if any properties are identified as changed.
  # DB2 doesn't support any method for modifying an existing catalog entry so
  # we need to uncatalog and re-create the entry
  #
  def flush
    destroy
    create
  end

  # Generic handler to parse the output from db2 list * directory commands.
  # it takes a string dump of the output commands and builds a hash
  # consisting of keys of identifier and the value as a hash of configuration
  # options matched in the keymap hash
  #
  def parse_output (rawstr, identifier, keymap, sep=/\W+=\W/, del=/\n\W*/)
    data_arr = rawstr.split(del)
    result = {}
    ident = nil
    data_arr.each do |line|
      param, val = line.split(sep)
      keymap.each do |matcher, key|
        if param =~ matcher
          if key == identifier
            ident = val
            result[ident] = {}
          else
            if ident
              result[ident][key] = val
            end
          end
        end
      end
    end
    result
  end
end
