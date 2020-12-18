require "gobject/gtk/autorun"

module Crycord::GUI
  extend self

  def run_cmd(cmd, args)
    stdout = IO::Memory.new
    stderr = IO::Memory.new
    status = Process.run(cmd, args: args, output: stdout, error: stderr)
  
    output = stderr.to_s.size == 0 ? stdout.to_s : stderr.to_s
    output
  end
  
  builder = Gtk::Builder.new_from_file "#{__DIR__}/crycord-GUI.glade"
  builder.connect_signals
  
  if !File.exists?("./crycord") && !File.exists?("/bin/crycord") && !File.exists?("/usr/bin/crycord")
    not_found_window = Gtk::Window.cast builder["not_found_window"]
    not_found_window.show_all
  else
    local = File.exists?("./crycord") ? "./" : ""
    version = {{ `shards version #{__DIR__}`.chomp.stringify }}
    command_args = [] of String
  
    css_path = Gtk::FileChooserButton.cast(builder["css_path"])
    asar_path = Gtk::FileChooserButton.cast(builder["asar_path"])
  
    force_asar = Gtk::Switch.cast(builder["force_asar"])
    group_switches = [Gtk::Switch.cast(builder["extra"])]
  
    # Hash(String, Array(Gtk::*))
    extra_plugins = {"extra" => [Gtk::Switch.cast(builder["unrestricted_resize"])]}
  
    about_button = Gtk::Button.cast(builder["about_button"])
    about_window = Gtk::Window.cast builder["about_window"]
    about_text = Gtk::TextView.cast(builder["about_text"])
  
    run_button = Gtk::Button.cast(builder["run_button"])
    revert_button = Gtk::Button.cast(builder["revert_button"])
  
    # Handle the force path switch
    force_asar.on_state_set do |e|
      force_asar.state = !force_asar.state
      asar_path.sensitive = !force_asar.state
      true
    end
  
    # Handle the plugin switches
    group_switches.each do |group|
      group.on_state_set do |e|
        e.state = !e.state
        # Group switches switch all their child plugins
        extra_plugins[group.name].each do |x|
          x.state = !x.state
          x.active = x.state
        end
        true
      end
      # Create event listeners for all plugins
      extra_plugins[group.name].each do |plugin|
        plugin.on_state_set do |x|
          # If all plugins in a group are on, then turn the group switch on as well
          group.active = extra_plugins[group.name].reject { |y| y.active }.size == 0
          true
        end
      end
    end
  
    # Show the about window when the about button is clicked
    about_button.on_clicked do |button|
      output = Crycord::GUI.run_cmd("#{local}crycord", ["-v"]).gsub(/\e\[[0-9;]*m/, "")
      version_info = <<-String
          Crycord: #{output.split(" ")[-1]}
          Crycord-GUI: #{version}
          String
      about_text.buffer.set_text(version_info, version_info.size)
      about_window.show_all
    end
  
    # Hide about window when user clicks the close button
    Gtk::Button.cast(builder["about_close_button"]).connect "clicked", &->about_window.hide
  
    command = Gtk::Label.cast(builder["command"])
    terminal = Gtk::TextView.cast(builder["terminal"])
    tabs = Gtk::Notebook.cast(builder["tabs"])
  
    tabs.after_switch_page do |x|
      run_button.sensitive = false
      next unless x.page == 2
      css = css_path.filename
      asar = asar_path.filename
      next unless !css.nil?
      args = [] of String
      args = args + ["-c", css]
      if !force_asar.active && !asar.nil?
        args = args + ["-f", asar]
      end
      plugins = [] of String
      groups = [] of String
      group_switches.each do |group|
        if group.active
          groups << group.name
        else
          extra_plugins[group.name].each do |plugin|
            plugins << plugin.name if plugin.active
          end
        end
      end
      args = args + ["-g", groups.join(",")] if groups.size != 0
      args = args + ["-p", plugins.join(",")] if plugins.size != 0
      run_button.sensitive = true
      command_args = args
      full_command = "crycord " + args.join(" ")
      command.label = full_command
    end
  
    run_button.on_clicked do |e|
      output = Crycord::GUI.run_cmd("#{local}crycord", command_args.join(" ").split(" ")).gsub(/\e\[[0-9;]*m/, "")
      output = "Done!" if output.size == 0
      terminal.buffer.set_text(output, output.size)
    end
  
    revert_button.on_clicked do |e|
      output = Crycord::GUI.run_cmd("#{local}crycord", ["-r"]).gsub(/\e\[[0-9;]*m/, "")
      output = "Done!" if output.size == 0
      terminal.buffer.set_text(output, output.size)
    end
  
    window = Gtk::Window.cast builder["main_window"]
    window.show_all
  end
  
end
