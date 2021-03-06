require "spec_helper_with_rad"

describe "Forgery protection" do    
  rad.web
  rad.reset :conveyors
  
  with_prepare_params
    
  isolate :conveyors

  before :all do    
    class ForgerySpecHelper < Rad::Conveyors::Processor
      def call
        block = workspace.check_forgery.before_request
        block.call workspace if block
        workspace.before_request_done = true

        next_processor.call

        block = workspace.check_forgery.after_request
        block.call workspace if block
        workspace.after_request_done = true    
      end
    end
    
    rad.conveyors.web do |web|
      web.use Rad::Http::Processors::PrepareParams
      web.use Rad::Http::Processors::EvaluateFormat
      web.use ForgerySpecHelper
      web.use Rad::Processors::PrepareAutenticityToken
      web.use Rad::Controller::Processors::ControllerCaller
    end          

    class ::AnRemote
      inherit Rad::Controller::Http
      
      protect_from_forgery only: :protected_method
      
      def protected_method
        render inline: 'protected result'
      end
      
      def method_without_protection
        render inline: 'result'
      end
      
      def dumb_method; end
    end
  end
  
  after :all do
    rad.reset :conveyors
    remove_constants %w(AnRemote ForgerySpecHelper)
  end
  
  before do
    rad.http.stub(:session).and_return({'key' => 'session_id'})
  end
  
  def check_forgery opt    
    workspace = nil 
    
    result = rad.http.call(rad.http.mock_environment, check_forgery: opt.to_openobject) do |c|
      c.call
      workspace = rad[:workspace]
    end
        
    workspace.before_request_done.should be_true
    workspace.after_request_done.should be_true
    workspace
  end
  
  it "should set :authenticity_token only for :get and 'html' request" do
    check_forgery(
      before_request: lambda{|workspace|        
        workspace.env['REQUEST_METHOD'] = 'GET'        
        workspace.env['CONTENT_TYPE'] = 'text/html'
        workspace.class = AnRemote
        workspace.method_name = :dumb_method
      },
      after_request: lambda{|workspace|
        workspace.request.session['authenticity_token'].should_not be_blank
      }
    )
    
    # post
    check_forgery(
      before_request: lambda{|workspace|        
        workspace.env['REQUEST_METHOD'] = 'POST'        
        workspace.env['CONTENT_TYPE'] = 'text/html'
        workspace.class = AnRemote
        workspace.method_name = :dumb_method
      },
      after_request: lambda{|workspace|
        workspace.request.session['authenticity_token'].should be_blank
      }
    )
  end
  
  it "should check any non :get request with browser's formats for :authenticity_token" do
    lambda{
      check_forgery(
        before_request: lambda{|workspace|        
          workspace.env['REQUEST_METHOD'] = 'POST'        
          workspace.env['CONTENT_TYPE'] = 'text/html'
          workspace.class = AnRemote
          workspace.method_name = 'protected_method'
        }
      )
    }.should raise_error(/invalid authenticity token/)
  end
    
  it "should pass request with correct authenticity_token" do
    check_forgery(
      before_request: lambda{|workspace|
        workspace.env['REQUEST_METHOD'] = 'POST'        
        workspace.env['CONTENT_TYPE'] = 'text/html'
        workspace.request.session['authenticity_token'] = 'secure token'
        workspace.params['authenticity_token'] = 'secure token'
        workspace.class = AnRemote
        workspace.method_name = 'protected_method'
      },
      after_request: lambda{|workspace|
        workspace.content.should == "protected result"
      }
    )
  end
    
  it "should not check request with non-browser content type" do
    check_forgery(
      before_request: lambda{|workspace|
        workspace.env['REQUEST_METHOD'] = 'POST'        
        workspace.env['CONTENT_TYPE'] = 'non-browser-format'
        workspace.class = AnRemote
        workspace.method_name = 'protected_method'
      },
      after_request: lambda{|workspace|
        workspace.content.should == "protected result"
      }
    )
  end
    
  it "should not check request with non-browser format" do
    check_forgery(
      before_request: lambda{|workspace|
        workspace.env['REQUEST_METHOD'] = 'POST'        
        workspace.env['CONTENT_TYPE'] = 'text/html'
        workspace.params['format'] = 'json'
        workspace.class = AnRemote
        workspace.method_name = 'protected_method'
      },
      after_request: lambda{|workspace|
        workspace.content.should == "protected result"
      }
    )
  end
  
  it "should not protect non protected methods" do
    check_forgery(
      before_request: lambda{|workspace|        
        workspace.env['REQUEST_METHOD'] = 'POST'        
        workspace.env['CONTENT_TYPE'] = 'text/html'
        workspace.class = AnRemote
        workspace.method_name = 'method_without_protection'
      },
      after_request: lambda{|workspace|
        workspace.content.should == "result"
      }
    )    
  end
  
  # it "OUTDATED should use :session_authenticity_token from params (for flash support)" do
  #   check_forgery(
  #     before_request: lambda{|workspace|
  #       workspace.env['REQUEST_METHOD'] = 'POST'        
  #       workspace.params.format = 'text/html'
  #       # workspace.params['session_authenticity_token'] = 'secure token'
  #       workspace.params['authenticity_token'] = 'secure token'
  #       workspace.class = AnRemote
  #       workspace.method_name = 'protected_method'
  #     },
  #     after_request: lambda{|workspace|
  #       workspace.content.should == "protected result"
  #     }
  #   )
  # end

end