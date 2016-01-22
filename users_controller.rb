def authorize
      render(json: params[:error]) && return if params[:error]
      unless params[:code]
        redirect_uri = "#{api_v1_ig_authorize_url}?access_token=#{params[:access_token]}"
        instagram_call = "https://api.instagram.com/oauth/authorize/?client_id=#{ENV['ig_client_id']}&redirect_uri=#{redirect_uri}&scope=likes+relationships&response_type=code"
        redirect_to instagram_call
      else
        uri = URI('https://api.instagram.com/oauth/access_token')
        ig_params = { code: params[:code],
                      client_id: ENV['ig_client_id'],
                      client_secret: ENV['ig_client_secret'],
                      grant_type: 'authorization_code',
                      redirect_uri: "#{api_v1_ig_authorize_url}?access_token=#{params[:access_token]}" }
        res = Net::HTTP.post_form(uri, client_id: ig_params[:client_id],
                                       client_secret: ig_params[:client_secret],
                                       grant_type: ig_params[:grant_type],
                                       redirect_uri: ig_params[:redirect_uri],
                                       code: params[:code])
        hash = ActiveSupport::JSON.decode(res.body)
        logger.ap hash
        if hash['code'] && hash['code'] == 400
          redirect_to("#{Rails.application.config.front_end_url}/my-stats?status=error&code=1003") && return
        end
        params[:ig_user] = hash['user']
        params[:ig_user][:access_token] = hash['access_token']
        if current_user.ig_users.exists?(params[:ig_user][:id])
          redirect_to("#{Rails.application.config.front_end_url}/my-stats?status=error&code=1001") && return
        end

        if IgUser.exists?(params[:ig_user][:id])
          ig_user = IgUser.find(params[:ig_user][:id])
          if ig_user.brand && ig_user.brand_id != current_user.id
            redirect_to("#{Rails.application.config.front_end_url}/my-stats?status=error&code=1002") && return
            # render json: {errors: ["Account already linked. Request management permissions from owner"]} and return
          else
            ig_user.update(ig_user_params)
            ig_user.brand = current_user
          end
        else
          ig_user = current_user.ig_users.create(ig_user_params)
          current_user.ig_user = ig_user unless current_user.ig_user
        end
        ig_user.save
        current_user.save
        ap 'redirecting to stats'
        redirect_to("#{Rails.application.config.front_end_url}/my-stats?status=success&id=#{ig_user.id}") && return
      end
    end