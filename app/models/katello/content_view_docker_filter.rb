module Katello
  class ContentViewDockerFilter < ContentViewFilter
    CONTENT_TYPE = 'docker'.freeze

    has_many :docker_rules, :dependent => :destroy, :foreign_key => :content_view_filter_id,
             :class_name => "Katello::ContentViewDockerFilterRule"
    validates_lengths_from_database

    # Returns a set of Pulp/MongoDB conditions to filter out manifests in the
    # repo repository that match parameters
    #
    # @param repo [Repository] a repository containing manifests to filter
    # @return [Array] an array of hashes with MongoDB conditions
    def generate_clauses(repo)
      manifest_tags = []

      self.docker_rules.each do |rule|
        manifest_tags.concat(query_manifests(repo, rule))
      end

      { "_id" => { "$in" => manifest_tags } } unless manifest_tags.empty?
    end

    protected

    def query_manifests(repo, rule)
      query_name = rule.name.tr("*", "%")
      tags_query = ::Katello::DockerTag.where(:repository => repo).
                                        where(:docker_taggable_type => DockerManifest.name).
                                        where("name ilike ?", query_name).
                                        select(:docker_taggable_id)

      query = DockerManifest.in_repositories(repo).where("id in (#{tags_query.to_sql})")
      names = query.all.collect do |manifest|
        manifest.docker_tags.where(:repository => repo).all.collect do |tag|
          tag.uuid
        end
      end
      names.flatten.uniq
    end
  end
end
