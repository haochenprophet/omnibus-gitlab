#
# Copyright:: Copyright (c) 2015 GitLab B.V.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

name "gitlab-git-http-server"
default_version "1de27beb5a07e5fec8b37b460ce1bed35d28e2a0" # 0.2.4

source :git => "https://gitlab.com/gitlab-org/gitlab-git-http-server.git"

build do
  make "install PREFIX=#{install_dir}/embedded"
end