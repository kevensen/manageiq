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

    it "returns a hash of a successfully created resource " do
      VCR.use_cassette("mixins/#{described_class.name.underscore}/create_resource",
                       :match_requests_on => [:path,]) do
        test_service_two = @test_service.dup
        test_service_two[:metadata][:name] = 'mysql2'
        test_service_two_from_provider = FactoryGirl.create(:container_service, :name => 'mysql2', :container_project => @test_project)
        result = @test_project.create_resource(test_service_two.to_h)

        expect(result.kind_of?(Hash)).to be_truthy
        expect(result).to eq(test_service_two_from_provider.get_from_provider)
      end
    end
  end
end
