# Copyright (c) 2011 VMware, Inc.  All Rights Reserved.
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

opts :reboot do
  summary "Reboot a host"
  arg :host, nil, :lookup => VIM::HostSystem, :multi => true
  opt :force, "Reboot even if in maintenance mode", :default => false
end

def reboot hosts, opts
  tasks hosts, :RebootHost, :force => opts[:force]
end


opts :evacuate do
  summary "vMotion all VMs away from this host (experimental)"
  arg :src, nil, :lookup => VIM::HostSystem
  arg :dst, nil, :lookup => VIM::ComputeResource, :multi => true
  opt :num, "Maximum concurrent vMotions", :default => 4
end

def evacuate src, dsts, opts
  vim = src._connection
  vms = src.vm
  dst_hosts = dsts.map(&:host).flatten
  checks = ['cpu', 'software']

  dst_hosts.reject! { |host| host == src ||
                             host.runtime.connectionState != 'connected' ||
                             host.runtime.inMaintenanceMode }

  candidates = {}
  vms.each do |vm|
    required_datastores = vm.datastore
    result = vim.serviceInstance.QueryVMotionCompatibility(:vm => vm,
                                                           :host => dst_hosts,
                                                           :compatibility => checks)
    result.reject! { |x| x.compatibility != checks ||
                         x.host.datastore & required_datastores != required_datastores }
    candidates[vm] = result.map { |x| x.host }
  end

  if candidates.any? { |vm,hosts| hosts.empty? }
    puts "The following VMs have no compatible vMotion destination:"
    candidates.select { |vm,hosts| hosts.empty? }.each { |vm,hosts| puts " #{vm.name}" }
    return
  end

  tasks = candidates.map do |vm,hosts|
    host = hosts[rand(hosts.size)]
    vm.MigrateVM_Task(:host => host, :priority => :defaultPriority)
  end

  progress tasks
end


opts :enter_maintenance_mode do
  summary "Put hosts into maintenance mode"
  arg :host, nil, :lookup => VIM::HostSystem, :multi => true
  opt :timeout, "Timeout", :default => 0
end

def enter_maintenance_mode hosts, opts
  tasks hosts, :EnterMaintenanceMode, :timeout => opts[:timeout]
end


opts :exit_maintenance_mode do
  summary "Take hosts out of maintenance mode"
  arg :host, nil, :lookup => VIM::HostSystem, :multi => true
  opt :timeout, "Timeout", :default => 0
end

def exit_maintenance_mode hosts, opts
  tasks hosts, :ExitMaintenanceMode, :timeout => opts[:timeout]
end
