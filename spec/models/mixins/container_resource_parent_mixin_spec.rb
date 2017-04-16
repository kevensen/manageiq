describe ContainerResourceParentMixin do
  describe 'container_project' do
    before(:each) do
      allow(MiqServer).to receive(:my_zone).and_return("default")
      hostname = 'host.example.com'
      token = 'theToken'

      @ems = FactoryGirl.create(
        :ems_openshift,
        :name                      => 'OpenShiftProvider',
        :connection_configurations => [{:endpoint       => {:role       => :default,
                                                            :hostname   => hostname,
                                                            :port       => "8443",
                                                            :verify_ssl => OpenSSL::SSL::VERIFY_NONE},
                                        :authentication => {:role     => :bearer,
                                                            :auth_key => token,
                                                            :userid   => "_"}},
                                       {:endpoint       => {:role     => :hawkular,
                                                            :hostname => hostname,
                                                            :port     => "443"},
                                        :authentication => {:role     => :hawkular,
                                                            :auth_key => token,
                                                            :userid   => "_"}}]
      )

      @test_project = FactoryGirl.create(:container_project, :name => 'testproject', :ext_management_system => @ems)

      @test_service = Kubeclient::Resource.new
      @test_service[:apiVersion] = 'v1'
      @test_service[:kind] = 'Service'
      @test_service[:metadata] = {}
      @test_service[:metadata][:name] = 'mysql'
      @test_service[:metadata][:namespace] = 'testproject'
      @test_service[:metadata][:labels] = {}
      @test_service[:metadata][:labels][:app] = 'cakephp-mysql-example'
      @test_service[:metadata][:labels][:template] = 'cakephp-mysql-example'
      @test_service[:metadata][:annotations] = {}
      @test_service[:metadata][:annotations][:description] = 'Exposes the database server'
      @test_service[:spec] = {}
      @test_service[:spec][:ports] = [{:name => 'mysql', :protocol => 'TCP', :port => 3306, :targetPort => 3306}]
      @test_service[:spec][:selector] = {}
      @test_service[:spec][:selector][:name] = 'mysql'
    end

    # The *.ext_management_system.connect_client method is the only
    # method in the provider (container_manager) on which this mixin relies
    it "ems responds to connect_client" do
      expect(@test_project.ext_management_system.respond_to?(:connect_client)).to be_truthy
    end

    # These tests are boiler plate
    it "responds to get_resource_by_name" do
      expect(@test_project.respond_to?(:get_resource_by_name)).to be_truthy
    end

    it "responds to get_resources" do
      expect(@test_project.respond_to?(:get_resources)).to be_truthy
    end

    it "responds to create_resource" do
      expect(@test_project.respond_to?(:create_resource)).to be_truthy
    end

    it "responds to patch_resource" do
      expect(@test_project.respond_to?(:patch_resource)).to be_truthy
    end

    it "responds to send_method" do
      expect(@test_project.respond_to?(:send_method)).to be_falsey
    end

    it "ems responds to ext_management_system" do
      expect(@test_project.respond_to?(:ext_management_system)).to be_truthy
    end

    it "gets resources yields an array" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruces",
                       :match_requests_on => [:path,]) do
        results = @test_project.get_resources('Services')
        expect(results.kind_of?(Array)).to be_truthy
      end
    end

    it "gets resources yields an array even if only a single element" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruces_one",
                       :match_requests_on => [:path,]) do
        results = @test_project.get_resources('BuildConfigs')
        expect(results.kind_of?(Array)).to be_truthy
      end
    end

    it "gets resources yields an array with each element a hash" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruces",
                       :match_requests_on => [:path,]) do
        results = @test_project.get_resources('Services')
        results.each do |result|
          expect(result.kind_of?(Hash)).to be_truthy
        end
      end
    end

    it "gets resources only in testproject namespace" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruces",
                       :match_requests_on => [:path,]) do
        results = @test_project.get_resources('Services')
        results.each do |result|
          expect(result[:metadata][:namespace].eql?('testproject')).to be_truthy
        end
      end
    end

    it "gets single resource by name in testproject namespace" do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce_by_name",
                       :match_requests_on => [:path,]) do
        result = @test_project.get_resource_by_name('mysql', 'Service')
        expect(result[:metadata][:namespace].eql?('testproject'))
        expect(result.kind_of?(Hash)).to be_truthy
      end
    end

    it "returns nil if resource with name doesn't exist " do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/get_resoruce_by_name_nil",
                       :match_requests_on => [:path,]) do
        result = @test_project.get_resource_by_name('wrongservice', 'Service')
        expect(result.nil?).to be_truthy
      end
    end

    it "raises an exception if resource being created already exists " do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/create_existing_resource",
                       :match_requests_on => [:path,]) do
        expect { @test_project.create_resource(@test_service.to_h) }.to raise_error(MiqException::MiqProvisionError)
      end
    end

    it "returns a hash of a successfully created resource " do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/create_new_resource",
                       :match_requests_on => [:path,]) do
        test_service_two = @test_service.dup
        test_service_two[:metadata][:name] = 'mysql2'
        expect(@test_project.create_resource(test_service_two.to_h).kind_of?(Hash)).to be_truthy
      end
    end

    it "returns a hash of a successfully patched resource " do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/patch_resource",
                       :match_requests_on => [:path,]) do
        test_service_two = @test_service.dup
        test_service_two[:metadata][:name] = 'mysql2'
        expect(@test_project.create_resource(test_service_two.to_h).kind_of?(Hash)).to be_truthy
      end
    end
  end
end
