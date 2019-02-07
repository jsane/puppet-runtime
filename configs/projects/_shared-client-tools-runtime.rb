# This project is designed for reuse by branch-specific client-tools-runtime configs;
# See configs/projects/client-tools-runtime-<branchname>.rb
unless defined?(proj)
  warn('This is the base project for the client-tools runtime.')
  warn('Please choose one of the other client-tools projects instead.')
  exit 1
end

proj.setting(:runtime_project, 'client-tools')
proj.setting(:openssl_version, '1.0.2')

proj.generate_archives true
proj.generate_packages false

proj.description "The client-tools runtime contains third-party components needed for client-tools"
proj.license "See components"
proj.vendor "Puppet, Inc.  <info@puppet.com>"
proj.homepage "https://puppet.com"
proj.identifier "com.puppetlabs"
proj.version_from_git

platform = proj.get_platform

proj.setting(:artifactory_url, "https://artifactory.delivery.puppetlabs.net/artifactory")
proj.setting(:buildsources_url, "#{proj.artifactory_url}/generic/buildsources")

if platform.is_windows?
  # Windows Installer settings.
  proj.setting(:company_id, "PuppetLabs")
  proj.setting(:product_id, "Client")
  if platform.architecture == "x64"
    proj.setting(:base_dir, "ProgramFiles64Folder")
  else
    proj.setting(:base_dir, "ProgramFilesFolder")
  end

  proj.setting(:prefix, File.join("C:", proj.base_dir, proj.company_id, proj.product_id, 'tools'))
else
  proj.setting(:prefix, "/opt/puppetlabs/client-tools")
end

proj.setting(:bindir, File.join(proj.prefix, "bin"))
proj.setting(:libdir, File.join(proj.prefix, "lib"))
proj.setting(:includedir, File.join(proj.prefix, "include"))
proj.setting(:datadir, File.join(proj.prefix, "share"))
proj.setting(:mandir, File.join(proj.datadir, "man"))

proj.setting(:host, "--host #{platform.platform_triple}") if platform.is_windows?
proj.setting(:platform_triple, platform.platform_triple)

if platform.is_macos?
  # For OS X, we should optimize for an older architecture than Apple
  # currently ships for; there's a lot of older xeon chips based on
  # that architecture still in use throughout the Mac ecosystem.
  # Additionally, OS X doesn't use RPATH for linking. We shouldn't
  # define it or try to force it in the linker, because this might
  # break gcc or clang if they try to use the RPATH values we forced.
  proj.setting(:cppflags, "-I#{proj.includedir}")
  proj.setting(:cflags, "-march=core2 -msse4 #{proj.cppflags}")
  proj.setting(:ldflags, "-L#{proj.libdir} ")
elsif platform.is_windows?
  arch = platform.architecture == "x64" ? "64" : "32"
  proj.setting(:gcc_root, "C:/tools/mingw#{arch}")
  proj.setting(:gcc_bindir, "#{proj.gcc_root}/bin")
  proj.setting(:tools_root, "C:/tools/pl-build-tools")
  proj.setting(:chocolatey_bin, 'C:/ProgramData/chocolatey/bin')
  proj.setting(:cppflags, "-I#{proj.tools_root}/include -I#{proj.gcc_root}/include -I#{proj.includedir}")
  proj.setting(:cflags, "#{proj.cppflags}")
  proj.setting(:ldflags, "-L#{proj.tools_root}/lib -L#{proj.gcc_root}/lib -L#{proj.libdir} -Wl,--nxcompat -Wl,--dynamicbase")
  proj.setting(:cygwin, "nodosfilewarning winsymlinks:native")
elsif platform.name =~ /^redhatfips-7-.*/
  # Link against the system openssl instead of our vendored version:
  proj.setting(:system_openssl, true)
else
  proj.setting(:cppflags, "-I#{proj.includedir} -I/opt/pl-build-tools/include")
  proj.setting(:cflags, "#{proj.cppflags}")
  proj.setting(:ldflags, "-L#{proj.libdir} -L/opt/pl-build-tools/lib -Wl,-rpath=#{proj.libdir}")
end

# What to build?
# --------------

# Common deps
proj.component "runtime-client-tools"
unless proj.settings[:system_openssl]
  proj.component "openssl-#{proj.openssl_version}"
end
proj.component "curl"
proj.component "puppet-ca-bundle"
proj.component "libicu"

# What to include in package?
proj.directory proj.prefix

# Export the settings for the current project and platform as yaml during builds
proj.publish_yaml_settings

proj.timeout 7200 if platform.is_windows?
