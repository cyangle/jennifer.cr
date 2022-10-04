require "../spec/spec_helper"

class TestUser < Jennifer::Model::Base
  mapping(
    id: Primary32,
    email: String?,
  )
  has_many :memberships, TeamMember
end

class TeamMember < Jennifer::Model::Base
  mapping(
    id: Primary32,
    test_user_id: Int32,
    team_id: Int32,
    role: Int32,
  )
  belongs_to :team, Team
  belongs_to :test_user, TestUser
end

class Team < Jennifer::Model::Base
  mapping(
    id: Primary32,
    name: String,
  )
  has_many :members, TeamMember
end

it "eager loads" do
  puts 1
  u = TestUser.new({email: "test@example.com"})
  u.save
  t = Team.new({name: "team"})
  t.save
  tm = TeamMember.new({test_user_id: u.id, team_id: t.id, role: 1})
  tm.save
  debugger
  all = Team.all.eager_load(members: [:test_user]).to_a
end
